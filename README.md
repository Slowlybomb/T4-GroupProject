# Team 4 Project - Rowing Computer "Gondoilier"
### Components of Software:

1) Firmware
    - Interface with sensors
        - Accelerometer;
        - Gyroscope;
        - GPS;
    - Detected strokes per minute.
    - Distance and time since the first stroke.
    -  Battery charge.
    -  Time per 500 m.
2)  Embedded UI
    -  Interface to view stats and control the device.
2) Communication
    - Wi-Fi or Bluetooth connection to phone or computer.
    - Possibility to add future connected devices, like a heart rate sensor or a boat impeller, etc.
3) Phone/Computer application
    - Phone app to connect to the device, store previous workouts, view graphs and GPS maps (strava like app).
    - Computer Interface to view more detailed information, like the raw accelerometer.
    - Possibility for a social aspect with a public feed in the app so that people can share their rows.

This project aims to create a fitness tracker specifically for rowing. Although the technology used is the same across most sports, the tracker could be repurposed for other applications. Using an accelerometer, we will gather data about the movement of the boat and put that into a trained tensor model, which will detect rowing strokes. We will extrapolate important information for the rower, and this will be presented on a nice UI on the device's screen. GPS data might be used to augment this if we have enough time to implement it. Paired with this will be a phone or desktop application where users can view the data of their rowing workout in more detail and interact with a social feed where they can post or view others' workouts. The device will communicate with the phone and or computer using wifi or Bluetooth, using direct peer-to-peer data transfer.


