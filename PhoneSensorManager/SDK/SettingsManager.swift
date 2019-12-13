//
//  SettingsManager.swift
//  Dashphone
//
//  Created by Larry Li on 8/11/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider


class SettingsManager : NSObject {
    
    // AWS Cognitio stuff
    var CognitoIdentityUserPoolRegion: AWSRegionType = .USWest2
    var CognitoIdentityUserPoolId = "us-west-2_o9hV8dncG"
    var CognitoIdentityUserPoolAppClientId = "28o5pat73uot08u58jvkt09025"
    var CognitoIdentityUserPoolAppClientSecret = "3s7rapoglfe3v44hmp6cvmsn1t0k6nip3cr7i2cop37ii8rul8i"
    var AWSCognitoUserPoolsSignInProviderKey = "UserPool2"
    
    // Facebook stuff
    var fbAppId : String = "847504025611771"
    var fbAppName : String = "Dashphone"
    
    // IoT Hub server
    var iotHubAddress : String = "52.43.181.166"
    
    // Speech
    var agentName: String = "Eva"
    
    // Stream key
    var streamKey: String = "live_467296932_6d4USlyTZF3038btEkGk41Gb1QjegS"
    var twitchPOP: String = "rtmp://live-hou.twitch.tv/app/"
        
    //==========================================================
    // Constructor
    //==========================================================
    override init() {
        super.init()
    }
}
