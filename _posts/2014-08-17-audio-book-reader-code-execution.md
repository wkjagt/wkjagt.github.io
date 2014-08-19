---
layout: post
title:  "RFID audio book reader PART 3: code execution"
date:   2014-08-18 15:53:50
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

