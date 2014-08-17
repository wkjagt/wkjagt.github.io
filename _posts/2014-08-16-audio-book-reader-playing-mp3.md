---
layout: post
title:  "RFID audio book reader: playing MP3 files"
date:   2014-08-16 15:53:50
---

I recently wrote about [how I built an audio book reader for my nearly blind grandfather](https://gist.github.com/wkjagt/814b3f62ea03c7b1a765) and [posted it to Hacker News](https://news.ycombinator.com/item?id=8177117). I got a lot of feedback and a lot of people tweeted me asking for more technical details about how I built it. So, I'll be writing a series of posts on this.

When I first got the Raspberry Pi I was prettu excited. I had heard a lot about this wonderful little Linux box and my inner geek was very happy to get my hands on one. After the initial phase of pure excitement, I had set myself a first goal: play MP3 files.

## Some initial configs

When ordered my RPi, I also got an SD card already containing Raspbian Wheezy, a Debian port for the Raspberry Pi, which made the setup extremely easy. A couple of important configurations need to be done though. You can do them on first boot, or skip them because you can't wait to play. In this case you can always go back to the configuration tool by running `raspi-config`. The most important options to set, are `expand_rootfs` and `ssh`. The first expands the partition to use the full SD card, and the second enables an ssh server, so we can access the RPi through ssh later on. SSH is very useful if you don't want to RPi running on your TV all the time. Something else I wanted to get out of the way was the login prompt on startup, which my grand father would never have to use (he doesn't even need to know there is a computer inside his player). Auto login behaviour is accomplished by modifying the system's inittab file, located at `/etc/inittab`. Later I actually realized that, to automatically start a script on boot, you don't need to be logged in, so if you're following along, you can skip this. But for completeness, and because you may want this behaviour for something else, I will include it anyway.

I commented out the following line

    1:2345:respawn:/sbin/getty --noclear 38400 tty1

and put this in its place:

    1:2345:respawn:/bin/login -f pi tty1 /dev/tty1 2>&1

After rebooting the RPi (`sudo reboot`) I was logged in automatically.

##  Playing MP3 files

For this project, I would need to control MP3 files from my python code. I had never done this before and the first thing I found that came close to what I needed, was the mixer module that's part of the pygame library. I won't bore you with the code I tried, because I didn't end up using it. I still don't know why, but in my version of pygame, the `pygame.mixer.music.set_pos()` method didn't exist. I briefly verified in the source, but couldn't even find a reference to it. Since I wasn't even sure pygame was the best option, I continued my search and found the very awesome [mpd](http://www.musicpd.org/) (music player daemon) which is a daemon that runs a server that plays audio and that is controlled by sending it commands over TCP. It runs really well on the Raspberry Pi. It can be easily installed (run `sudo apt-get update` first if this is your first interaction with `apt-get`) :

    sudo apt-get install mpd

The Python client [python-mpd](https://github.com/Mic92/python-mpd2) can be installed in any way you prefer. Instructions are in the GitHub repository. MPD is a daemon that accepts connections over TCP on a port (6600 by default, which was fine for me) and are controlled by sending it control strings. By using the python client I didn't need to worry about formatting the strings and sending them.

The way MPD works, doesn't allow us to just play audio files from any location (not that I know of anyway), you need to give it a location where it will look for them. The installation we just did, created a global config file at `/etc/mpd.conf`. The only setting we really care about for now, is where to place the audio files. I changed the default setting (which pointed to `/var/lib/mpd/music`) to a folder called `books` in my user folder (`/home/pi/books`). For this change to take effect you need to restart the daemon (`sudo /etc/init.d/mpd restart`).

MPD is now running exactly how I want and playing audio files from Python becomes really easy. To simply play a file "sometestfile.mp3", which should of course exist in our newly created books folder, could be done as follows:

{% highlight python %}
from mpd import MPDClient

client = MPDClient() # instantiate the client object
client.connect(host="localhost", port=6600) # connect to the mpd daemon
client.update() # update the mpd database with the files in our books folder
client.add("sometestfile.mp3") # add the file to the playlist
client.play() # play the playlist
{% endhighlight %}

There's a lot more mpd can do, but we'll get to that when we get to writing the actual code for the book player. Or to see the code my player uses, look at [this file](https://github.com/wkjagt/BookPlayer/blob/master/player.py)

## Audio through 3.5mm jack

One last detail before we continue. By default the RasPi sends audio over HDMI, and not to the 3.5mm jack I plan to use. I read somewhere that actually by default it detects where it should send it, and at the time of testing, mine was connected to a TV, so that's where it sent it, but I wanted to make sure it didn't automatically send it to HDMI by mistake when my grandfather got the player, so I found out how to configure the built-in audio mixer to always send audio to the analog headphone output (`cset` is to set a configuration variable, we're setting configuration number 3, which is the playback route, to 1, which is the analog out):

    sudo amixer cset numid=3 1

## PulseAudio

I found that the playback quality of the RPi when using the standard ALSA sound driver that comes with the Raspbian distribution was pretty good. It did however have one nasty habit: it would generate a loud sharp pop whenever playback was paused. Installing PulseAudio solved this problem, see [here](http://dbader.org/blog/crackle-free-audio-on-the-raspberry-pi-with-mpd-and-pulseaudio) for instructions.

This pretty much rounds up how to play audio files from Python code, which is an important part of the Python application that runs the audio book player. Another important part is reading RFID parts, which I will explain in a next post.