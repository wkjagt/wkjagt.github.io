---
layout: post
title:  "RFID audio book reader PART 5: finishing up"
date:   2014-09-13 15:53:50
tweettext: "The RFID audio book reader for my nearly blind grandfather, PART 5: finishing up."
---

In the last posts I described how I setup the Raspberry Pi to read RFID cards and play a corresponding collection of MP3 files. In this post I will explain the remaining steps to make the player completely functional: the buttons and the status light.


![](https://c4.staticflickr.com/4/3685/9206778089_2f19e21bc8_c.jpg)

## The buttons

The buttons may seem like the easiest part because a button is a very simple device. In the previous post I told you about interrupts and how they make the buttons work: the program detects changes in the level on the pins to which the buttons are connected, and executes corresponding code in a separate thread.

### Button bounce

The problem though with any button is that they "bounce":

> Contact bounce (also called chatter) is a common problem with mechanical switches and relays. Switch and relay contacts are usually made of springy metals. When the contacts strike together, their momentum and elasticity act together to cause them to bounce apart one or more times before making steady contact. The result is a rapidly pulsed electric current instead of a clean transition from zero to full current. The effect is usually unimportant in power circuits, but causes problems in some analogue and logic circuits that respond fast enough to misinterpret the on‑off pulses as a data stream.

From: [Wikipedia](http://en.wikipedia.org/wiki/Switch#Contact_bounce)

If this problem isn't solved in hardware (by using a capacitor) or in software (by detecting quick changes and waiting for the signal to settle), the program will interpret the bouncing of the button as multiple button presses and will behave in unpredictable ways.

You may remember the following code snippet from the previous post:

{% highlight python %}
GPIO.setup(9, GPIO.IN)
GPIO.add_event_detect(9, GPIO.FALLING, callback=self.player.rewind)
{% endhighlight %}

If you compare it to the code I actually use [here](https://github.com/wkjagt/BookPlayer/blob/master/main.py#L65), you'll see I pass an extra argument `bouncetime` to `GPIO.add_event_detect`, which is a value in milliseconds. I am not absolutely sure what the GPIO library does internally with this value, but I found the optimal values by experimentation, and by adjusting them later on when my grandfather was experiencing problems (I found out he keeps the buttons pressed a lot longer than me). Looking back, I think it would have been better to go for hardware debouncing, because the current version seems somewhat picky. My impression is that the complete sequence of press and "unpress" need to fall in the debounce time. But I could be wrong because I was adjusing these values over SSH from Canada while my brother was interpreting the results from what he was observing when my grandfather was using reader.


### pull up vs. pull down

You may also remember from the previous post that the program detects the falling edge on the button pin to run the corresponding code. As a reminder: this means that it's waiting for the voltage on the pin to go from high (3.3 v) to low (0 v). This normally means we need to make sure that the voltage on the pin is pulled up to a default state of 3.3 volts. This done by connecting the pin, through a very high value resitor, to the + 3.3 volts pin on the Raspberry Pi. However, the Rasperry Pi has built-in pull up and pull down resistors, so we don't need to do this. We can activate this with the `pull_up_down` argument to `GPIO.setup()` ([here](https://github.com/wkjagt/BookPlayer/blob/master/main.py#L66)).

In the previous post I left out button bounce and pull up to describe how I use interrupts. Adding these two to the previous example, we get:

{% highlight python %}
GPIO.setup(9, GPIO.IN, pull_up_down=GPIO.PUD_UP)
GPIO.add_event_detect(9, GPIO.FALLING,
                      callback=self.player.rewind, bouncetime=1000)
{% endhighlight %}

The button connects the pin to ground through a high value resistor (1.2 k ohms if I remember correctly) when pressed to make the state of the pin low.

## The status light

One detail I added, a bit for my own pleasure because I thought it looked nice, was a status light on the front of the reader. It has the following functions: it's off when the reader is powered off (obviously) or booting. It's on when the player has booted and is ready to use. It blinks slowly while playing. It will give three fast flashes when a button is pressed or an RFID card is placed on the reader (as a type of feedback). If blinks once every 1.5 seconds if the player is paused.

The logic for the status light runs in a separate thread, which is setup [here](https://github.com/wkjagt/BookPlayer/blob/master/main.py#L43). A slightly simplified version looks like this:

{% highlight python %}
# instantiate a status light object, and tell it the light is
# connected to pin 23
status_light = StatusLight(23)

# start a new thread and give it the start method on
# the status light object as target
thread = Thread(target=status_light.start)

# start the new thread
thread.start()
{% endhighlight %}

While the status light object is looping through "on" and "off" states in a pattern ("on" and "off" for blinking, just "on" for on, etc), the main thread can set the `action` property on the status light object to the name of a different pattern. For example [here](https://github.com/wkjagt/BookPlayer/blob/master/player.py#L70) the property is set to `blink`. The currently running pattern can also be interrupted by a different pattern by calling the `interrupt` method on the status light object. If for example, the player is playing a book, and the light blinks slowly, a button press action can insert three quick flashes into the running pattern, after which the active one continues.

###More...

I think I described the most important parts of how built my grandfather's RFID audio book player. I'm sure there are details I left out, because I think they were less interesting, or simply because I forgot. If anyone wants to know more, or needs help building a similar project, let me know in the comments, and I'll be glad to respond.