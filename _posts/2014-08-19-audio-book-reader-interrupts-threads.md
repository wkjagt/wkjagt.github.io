---
layout: post
title:  "RFID audio book reader PART 4: interrupts and thread safety"
date:   2014-08-19 15:53:50
tweettext: "The RFID audio book reader for my nearly blind grandfather, PART 4: interrupts and thread safety."
---

In the last two posts I described how I setup the Raspberry Pi to read MP3 files, and how I connected the RFID reader to read cards. Using Python code to wait for an RFID card of the reader was also covered. We'll also take a look at how the buttons work.


## How it all starts

When the Raspberry Pi that powers the audio book reader boots, it starts a service called [supervisord](http://supervisord.org/). Supervisord is a process that can be configured to keep other processes running. If, for whatever reason, the code on the Raspberry Pi crashes, supervisord will notice and restart it. An advantage of using supervisord is that it daemonizes my code, so I don't have to worry about daemonizing it myself (if you were to run the python code from the command line, it would stay in the foreground). Supervisord is also configured to start [`main.py`](https://github.com/wkjagt/BookPlayer/blob/1.0/main.py) as soon as the RPi boots, making the reader ready to be used.


## The main loop

Let's take a look at this file. If we execute `main.py`, it will create an instance of `BookReader` and call the `loop` method on it. Important to understand here are the following lines:

{% highlight python %}
def loop(self):
    while True:
        rfid_card = self.rfid_reader.read()

        if not rfid_card:
            continue
{% endhighlight %}

I left most of the code out, but the above lines show that this function enters in an endless loop (you can see the complete method [here](https://github.com/wkjagt/BookPlayer/blob/1.0/main.py#L87)). In each iteration of the loop, the `read` method is called on the `rfid_reader` object that is set on the book reader object. The code for the object that represents the RFID reader can be found [here](https://github.com/wkjagt/BookPlayer/blob/1.0/rfid.py). The most important lines in this method (leaving out some error handling) are:

 {% highlight python %}
 def read(self):
     rcv = self.port.read(self.string_length)

     if not rcv:
         return None

     tag = { "raw" : rcv,
             "mfr" : int(rcv[1:5], 16),
             "id" : int(rcv[5:11], 16),
             "chk" : int(rcv[11:13], 16)}
     
     return Card(tag)
{% endhighlight %}


We see that serial data is being read from `self.port`, which is an instance of `serial.Serial` (and was instantiated [here](https://github.com/wkjagt/BookPlayer/blob/1.0/rfid.py#L29)). This port was setup with a timeout of one second, which means this line of code will block for a maximum of one second. If during that second serial data was received on the port, the `rcv` variable will contain that data which is then used to instantiate and return a `Card` object (found [here](https://github.com/wkjagt/BookPlayer/blob/1.0/rfid.py#L55)). If no data was returned, the `rcv` value will contain a `None` object. You may remember from the [last post]({% post_url 2014-08-17-audio-book-reader-reading-rfid %}) that putting an RFID card on the reader only causes the id to be sent once. This means that this `read` method will almosy always block for precisely one second.

## Interrupts

The simplest way to check if a button is pressed, is to keep checking the state of the button in a loop, and wait for it to change. However, if the main loop spends most of its time being blocked by waiting on data on the serial port, we can't really use this loop to see if my grandfather has pressed a button because a button press is usually a lot shorter than one second so we may miss it if the button is pressed and released within the second that the loop was blocked on the serial port.

This is where interrupts come into play. You can read all about interrupts [here](http://en.wikipedia.org/wiki/Interrupt) but the main idea is that instead of continously checking the state of button ourselves from the code, we can use the button to send a signal to the processor and only act if this happens. If we take a look at the `setup_gpio` method in the `BookReader` class, we see how this is setup for the buttons of the book reader ([here](https://github.com/wkjagt/BookPlayer/blob/1.0/main.py#L59)). This method loops through the config values to setup each button. If we were to extract the setup of one of the buttons, it would look like this (I'm leaving out the last arguments on purpose, because they're not relevant just yet):

{% highlight python %}
GPIO.setup(9, GPIO.IN)
GPIO.add_event_detect(9, GPIO.FALLING, callback=self.player.rewind)
{% endhighlight %}

In the first line, we're setting up pin 9 (which is one of the physical pins on the RPi board) to be an input. After that we're setting up this pin to listen to interrupts using the `add_event_detect` method. The second argument here (`GPIO.FALLING`) says we want to listen for an *edge triggered* interrupt, and more specifically the transition of the voltage on the pin *from high to low* (the *falling edge*). If this happens, we want to call the `rewind` method on the `player` object that is set on the book reader object. In short: if the voltage on pin 9 drops from high to low, we call `self.player.rewind`.

The other three buttons function in the exact same way. They're all connected to their own pin, and all have their own callback on the `self.player` object.

## Threads and thread safety

The main loop described above runs in the main thread of the program. It keeps looping and blocking on the serial port. If an interrupt occurs on one of the button's pins a seperate thread is created to execute the code of the callback, in parallel with the main thread. This means that the main loop is not blocking the new thread. If for example, the pause button is pressed, a new thread is created, and the `pause` method is executed, which sends an instruction to the mpd server (that's playing the audio) to tell it to pause.

If you're using multiple threads like this, strange things can happen though. For example, within the main thread, the mpd server is constantly queried to get the current status (which includes information like the current volume, the track that's playing etc.). As you may remember from [this post]({% post_url 2014-08-16-audio-book-reader-playing-mp3 %}) this information is transmitted over a local port. If I don't keep thread safety in mind, pressing the pause button will spawn a thread that also communicates over this local port, and the two information streams will interfere. I actually encountered this bug while developing this code, which manifested itself by occasionaly throwing an exception when I pressed a button while a book was playing. The pause command (in the new thread) to the mpd server received information it shouldn't, and the status command in the main thread was receiving an incomplete one.

The problem is that both threads are sharing a resource (the mpd server), and they're doing it at the same time. A solution (the one that I chose), is for a thread to lock access to the resource while it's using it. I extended the `MPDClient` class into my own `LockableMPDClient` (taken from [this example](https://github.com/Mic92/python-mpd2/blob/master/examples/locking.py)).

{% highlight python %}
class LockableMPDClient(MPDClient):
    def __init__(self, use_unicode=False):
        super(LockableMPDClient, self).__init__()
        self.use_unicode = use_unicode
        self._lock = Lock()
    def acquire(self):
        self._lock.acquire()
    def release(self):
        self._lock.release()
    def __enter__(self):
        self.acquire()
    def __exit__(self, type, value, traceback):
        self.release()
{% endhighlight %}

When instantiating the mpd client, we give the object a `threading.Lock` object, which provides a very easy locking interface. Since the mpd client object is shared by all threads, once one thread has aquired the lock, another one can't acquire it until it's released. If you're familiar with python, you'll notice the `__enter__` and `__exit__` methods. Providing these two methods allow me to do the following whenever I need to call a method on the mpd client:

{% highlight python %}
def get_status(self):
    with self.mpd_client:
        return self.mpd_client.status()
{% endhighlight %}

When a `with` statement is executed, the `__enter__` method is called on the object. When all code within the `with` block is executed, `__exit__` is called on the object, meaning that for the duration of `self.mpd_client.status()` access to the mpd client is locked for all other threads. Actually this use of `with` is only half of what it can do because I don't need context guarding (read more [here](http://effbot.org/zone/python-with-statement.htm)) but it is enough to achieve locking.

In [the next post]({% post_url 2014-09-13-audio-book-reader-finishing-up %}) I will describe in more detail how I implemented the buttons, because even though they may seem like the easiest to implement, they're actually not.