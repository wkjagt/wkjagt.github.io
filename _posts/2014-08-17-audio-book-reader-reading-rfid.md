---
layout: post
title: "RFID audio book reader: reading RFID cards"
date:   2014-08-17 15:53:50
---


In a [previous post]({% post_url 2014-08-16-audio-book-reader-playing-mp3 %}), the Raspberry Pi has been setup to play MP3 files from a Python script, and play the sound through the headphone output. Nothing out of the ordinary so far, and any MP3 player can do the same. However, we need a way to control the book reader in a way that doesn't hinder people with poor or no eyesight, and this is where all other MP3 players fall short because they use touch screens with tiny characters, or tiny buttons that require good eyesight. The solution I chose is to have the player read [RFID](http://en.wikipedia.org/wiki/Radio-frequency_identification) cards to select the books that are stored on it.

## Connecting the RFID reader

I ordered the cheapest RFID reader I could find, because they basically all do the same thing: read an RFID tag and transmit the ID of the card over a serial signal. Some readers offer NFC capabilities (allowing you to store a small amount of data on the card), but I didn't need that. I got mine from [robotshop.com](http://www.robotshop.com/ca/) (I am in Canada, and like to buy locally). It's an Electronic Brick from Seeedstudio ([this one](http://www.seeedstudio.com/depot/Electronic-brick-125Khz-RFID-Card-Reader-p-702.html) which is now discontinued). I couldn't find anything on how to connect it to a Raspberry Pi, but since it communicates over standard [UART](http://en.wikipedia.org/wiki/Universal_asynchronous_receiver/transmitter), I assumed it couldn't be that hard if I just used the Python [serial](http://pyserial.sourceforge.net/) library.

### Voltage

Even though an RFID device outputs a pretty standard serial signal, something you really need to keep in mind if you don't want to damage your RPi, is that the voltage that the RFID reader outputs on the Tx (the transmitting pin) is 5 volts, and the Rx (the receiving pin) on the RasPi only expects 3.3 volts. Connecting this RFID reader directly to the Raspberry Pi would burn out the Rx pin in the best case. To bring the voltage down to 3.3 volts, I got a logic level converter. Hooking it up to the RasPi and the card reader is really simple, even though I did it wrong the first time, because I got confused by the labels on the converter. The 5 volt signal coming from the reader is connected to the RXI on the HV (high voltage) side of the converter, which makes a 3.3 volt signal available on the RXO pin on the LV (low voltage) side, which is then connected to the Rx pin of the RasPi. I found several descriptions of how to connect this converter, but the clearest I found was actually an image on [hackaday.com](http://hackaday.com/) ([this one](http://hackaday.com/2008/06/19/sparkfuns-logic-level-converter/)).

### Reading from serial

After this was connected correctly, reading RFID cards on the serial port can be done in only a couple of lines of code:

{% highlight python %}
# import the serial library providing all
# functionality to interact with serial ports
import serial

# "/dev/ttyAMA0" is the name of the serial port
# on the Raspberry Pi the RFID reader from Seeedstudio
# sends serial data at a baudrate of 9600 a timeout of
# 1 second wil wait for data on the serial port for
# one second before continueing
port = serial.Serial("/dev/ttyAMA0", baudrate=9600, timeout=1)

while True:
    # the RFID reader sends the data for one tag as a 14 character string
    rcv = self.port.read(14)
    print rcv
{% endhighlight %}

Even though this will successfully display the raw data from the RFID tag, it's not actually the id of the card. The details are available in the wiki of the reader ([here](http://www.seeedstudio.com/wiki/index.php?title=Electronic_brick_-_125Khz_RFID_Card_Reader)) but since this product has been retired by Seeedstudio since I got it, there won't be much value in me explaining it. The only information on how to get the actual card id I found was [this C library](https://github.com/johannrichard/SeeedRFIDLib/blob/master/SeeedRFIDLib.cpp) which was actually pretty trivial to express in Python code, which can be found in the code that runs on the audio book player [here](https://github.com/wkjagt/BookPlayer/blob/master/rfid.py)  .

Reading the RFID cards was easy, but as soon as I saw how the reader worked, I realized there was a flaw in my plan. I really wanted the play and pause of the audio playback to be controlled by the RFID card only. Placing the card on top would start playing the corresponding book, and removing it would pause it. I assumed I could "ping" the RFID reader for the id of the card within its range, but instead of this, the reader sends the id of the card over serial as soon as it's in range, and it does this only once. This meant I needed an additional button on the reader to be able to pause / resume playback. A small deception but four buttons is still very acceptable.

A short post, but it pretty much rounds up the implementation of the RFID reader in this project. In a next post I'll describe the implementation of the buttons.