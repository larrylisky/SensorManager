//
//  CommandDispatch.swift
//  Dashphone
//
//  Created by Larry Li on 7/15/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import Foundation
import AVFoundation


class CommandDispatch : NSObject {
    
    struct Command {
        var prompt : Bool
        var actions : [String]
        var param : String
        var function : (String) -> String?
    }
    
    private var prompt : [String] = []
    private var commandTemplates : [Command] = []
    private var extractedCommands : [Command] = []
    
    //==========================================================
    // Constructor
    //==========================================================
    override init() {
        super.init()
    }
    
    //==========================================================
    // Setup
    //==========================================================
    func setup(prompt: [String]) {
        sys.log("CommandDispatch", text: "init prompt to '\(prompt)'\n")
        setPrompt(prompt: prompt)
        sys.speech.outputDelegate = self
    }
    
    //==========================================================
    // Register commands
    //==========================================================
    open func registerCommand(command: Command) {
        commandTemplates.append(command)
        sys.log("CommandDispatch", text: "registered (actions=\(command.actions), param=\(command.param), function=\(String(describing: command.function))\n")
    }
    
    
    //==========================================================
    // Set the prompt phrase
    //==========================================================
    open func setPrompt(prompt: [String]) {
        sys.log("CommandDispatch", text: "set prompt to '\(prompt)'\n")
        self.prompt = prompt
    }
    
    
    //==========================================================
    // Check if EVA was prompted
    //==========================================================
    open func checkPrompt(text: String) -> (Bool, String) {
        var found : Bool = false
        var remainString : String = ""
        
        let string = String(text)
        for p in prompt {
            (found, remainString) = string.residual(of: String(p))
            if found {
                sys.log("CommandDispatch", text: "prompt detected\n")
                return (true, remainString)
            }
        }
        sys.log("CommandDispatch", text: "prompt not detected\n")
        return (false, remainString)
    }
    
    //==========================================================
    // Find subcommand strings
    //==========================================================
    open func findSubCommandStrings(command: String) -> [String] {
        var subCommandStrings : [String] = []
        var subCommandString : String = ""

        let words = command.split(separator: " " , maxSplits: 100, omittingEmptySubsequences: true)
        for word in words {
            if word == "and" {
                if subCommandString.count > 0 {
                    subCommandStrings.append(subCommandString)
                }
                subCommandString = ""
            }
            else {
                subCommandString = subCommandString + String(word) + " "
            }
        }
        if subCommandString.count > 0 {
            subCommandStrings.append(subCommandString)
        }
        return subCommandStrings
    }
    
    //==========================================================
    // Dispatch command
    //==========================================================
    open func dispatch(command: String) {
        
        var actionResult : (Bool, String)?

        sys.log("CommandDispatch", text: "dispatch - \(command)\n")
        
        // Check presence of prompt and follow-on compound command string
        let (prompted, commandString) = checkPrompt(text: command)
        
        // If prompted, process the rest of the string
        if commandString.count > 0 {
            actionResult = (false, "")
            for template in commandTemplates {
                for action in template.actions {
                    let (match, remainingString) = commandString.residual(of: action)
                    if match && ((template.prompt && prompted) || !template.prompt) {
                        sys.log("CommandDispatch", text: "acting on - \(action), with remainingString = '\(remainingString)'\n")
                        let words = remainingString.split(separator: " ", maxSplits: 100, omittingEmptySubsequences: true)
                        let arg = (template.param == "*" && words.count > 0) ? remainingString : template.param
                        if let response = template.function(arg) {
                            actionResult = (match, response)
                        }
                        break
                    }
                }
            }
            
            if let result = actionResult, result.0 == true {
                sys.speech.speak(result.1)
            }
            else if prompted {
                sys.log("CommandDispatch", text: "action not found\n")
                sys.speech.speak("I don't know this command.")
            }
        }
        else if prompted {
            sys.log("CommandDispatch", text: "action not provided\n")
            sys.speech.speak("Yes?")
        }
    }
    
}

////////////////////////////////////////////////////////////////////////////////
// SpeechManagerDelegate
////////////////////////////////////////////////////////////////////////////////
extension CommandDispatch : SpeechManagerOutputDelegate {
    
    // Called with recognition result
    func processOutput(manager: SpeechManager, input: String) {
        dispatch(command: input)
    }
}
