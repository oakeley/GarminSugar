# GarminSugar

## Disclaimer

**Never make a medical decision based on a reading that you see on this watchface. Always perform a fingerstick blood glucose to check first and seek medical advice if needed.**

## Watchface Description

This watchface is a port of the Amazfit Falcon watchface I have been using for a while. A special shout out to @nimrod100 for much of the work on the original watchface. The watchface pulls your blood sugar data from your phone and displays it on your watch. It also pulls your phone battery (bottom left) and your watch battery (bottom right). I never understood why watch vendors don't support this functionality (thanks @bigdigital for adding this feature request to the watchdrip app). The Amazfit Falcon watchface displayed their PAI (Physical Activity Index) on the top right of the watchface. As the Fenix 8 does not have a PAI feature, I have replaced it with the altitude/depth of dive instead (top right). Your step count is also included (top left).

## Functionality

This device depends on a local CGM app to provide the blood sugar data. Currently xDrip+ and Juggluco are supported.

1. In Juggluco you must enable the WatchDrip+ mode in the settings and the "xDrip-compatible" mode.
2. If you use xDrip+ then you need to enable the xDrip Web-Server in your xDrip+ app (_Settings -> Inter-App Settings -> enable "xDrip Web-Server," but not the "Open Web Server"_). If you have both xDrip+ and Juggluco installed then I recommend using Juggluco as it provides Libre glucose data without the annoying delay that xDrip+ has with Libre data.
3. You must install the WatchDrip+ app on your phone from bigdigital (https://www.patreon.com/posts/watchdrip-v0-3-1-99772487) this formats the data in a way that GarminSugar can read. It will also make it easier for you to switch between Garmin and Amazfit watches.
4. Unlike Amazfit, you do not need to install the WatchDrip+ app on your Garmin watch as my watchface manages all of the communication between the watch and the phone.

## Open Source

GarminSugar operates under the GPL v3 license. The source code is available on my github page (https://github.com/oakeley/GarminSugar)

## Participate in Watchface Creation

If you're interested in contributing or have ideas then reach out to me on Discord @draedie and please consider supporting Artem / bigdigital on Patreon as he puts in a lot of work to make the WatchDrip+ app. I am often on his dicord server a link for which can be found on his Patreon page (https://www.patreon.com/posts/watchdrip-server-77406652)

<img src="./fenix8.png" alt="GarminSugar Screenshot" width="400"/>
