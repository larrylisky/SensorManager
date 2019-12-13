//
//  ProfileManager.swift
//  Dashphone
//
//  Created by Larry Li on 8/11/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//
import Foundation
import AWSCognitoIdentityProvider
import FBSDKCoreKit
import FBSDKLoginKit


/////////////////////////////////////////////////////////////////////////
//  ProfileManagerSignInDelegate
/////////////////////////////////////////////////////////////////////////
protocol ProfileManagerSignInDelegate : NSObjectProtocol {
    // Called when sign in succeeded
    func signInSucceeded()
    // Called when sign in failed
    func signInFailed(_ error: NSError)
}

/////////////////////////////////////////////////////////////////////////
//  ProfileManagerSignUpDelegate
/////////////////////////////////////////////////////////////////////////
protocol ProfileManagerSignUpDelegate : NSObjectProtocol {
    // Called when confirmation code is sent to 'sentTo' for confirmation
    func signUpConfirming(_ sentTo: String?)
    // Called if user sign up failed
    func signUpFailed(_ error: NSError)
    // Called if user is already signed up
    func signedUpAlready()
}

/////////////////////////////////////////////////////////////////////////
//  ProfileManagerConfirmSignUpDelegate
/////////////////////////////////////////////////////////////////////////
protocol ProfileManagerConfirmSignUpDelegate : NSObjectProtocol {
    // Called when sign up is successfully confirmed
    func signUpConfirmed()
    // Called when sign up confirmation failed
    func signUpConfirmedFailed(_ error: NSError)
}

/////////////////////////////////////////////////////////////////////////
//  ProfileManagerNewPasswordDelegate
/////////////////////////////////////////////////////////////////////////
protocol ProfileManagerForgotPasswordRequestDelegate : NSObjectProtocol {
    // Called if new password request is sent to Cognito
    func forgotPasswordRequestSent()
}

/////////////////////////////////////////////////////////////////////////
//  ProfileManagerNewPasswordConformDelegate
/////////////////////////////////////////////////////////////////////////
protocol ProfileManagerForgotPasswordConfirmDelegate : NSObjectProtocol {
    // Called when new password is confirmed
    func forgotPasswordRequestConfirmed()
    // Called when new password failed to confirm
    func forgotPasswordRequestConfirmFailed(_ error: NSError)
}

/////////////////////////////////////////////////////////////////////////
//  ProfileManagerFBSignInDelegate
/////////////////////////////////////////////////////////////////////////
protocol ProfileManagerFBSignInDelegate : NSObjectProtocol {
    // Called when Facebook sign in succeeded
    func fbSignInSucceeded(_ userInfo: NSDictionary?)
    // Called when Facebook sign in cancelled
    func fbSignInCancelled()
    // Called when Facebook sign in failed
    func fbSignInFailed(_ error: Error)
}




/////////////////////////////////////////////////////////////////////////
//  ProfileManager
/////////////////////////////////////////////////////////////////////////
class ProfileManager : NSObject {
    
    // Delegates
    var signInDelegate : ProfileManagerSignInDelegate?
    var signUpDelegate : ProfileManagerSignUpDelegate?
    var confirmSignUpDelegate : ProfileManagerConfirmSignUpDelegate?
    var forgotPasswordRequestDelegate : ProfileManagerForgotPasswordRequestDelegate?
    var forgotPasswordConfirmDelegate : ProfileManagerForgotPasswordConfirmDelegate?
    var fbSignInDelegate : ProfileManagerFBSignInDelegate?
    
    /*
    sub : 8351a846-25d3-4165-bdbb-ef31e577b605
    email_verified : true
    phone_number_verified : false
    phone_number : +15555555
    email : larrylisky@gmail.com
    */
    struct PersonalData : Codable {
        var firstName : String = ""
        var lastName : String = ""
        var email: String = ""
        var emailVerified : Bool = false
        var phoneNumber: String = ""
        var phoneNumberVerified : Bool = false
        var sub : String = ""
        var fbID : String = ""
        var photoURL : URL?
        var address1 : String = ""
        var address2 : String = ""
        var city : String = ""
        var state : String = ""
        var zipCode : String = ""
    }
    
    // Local variables
    var newUsername: String = ""
    var loginViewController: LoginViewController?
    var navigationController: UINavigationController?
    var storyboard: UIStoryboard?
    var personal = PersonalData()
    
    // AWS Cognnito variables
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    var rememberDeviceCompletionSource: AWSTaskCompletionSource<NSNumber>?
    var pool: AWSCognitoIdentityUserPool?
    var user: AWSCognitoIdentityUser?
    var response: AWSCognitoIdentityUserGetDetailsResponse?

    // Facebook variables
    var usingFacebook : Bool = false
    var fbLoginManager : LoginManager?
    
    
    //=======================================================================
    // Setup - must be called before first use
    //=======================================================================
    func setup() {
    
        print("ProfileManager:  setup")
        
        // AWS Cognito
        AWSDDLog.sharedInstance.logLevel = .verbose
        let serviceConfiguration = AWSServiceConfiguration(
            region: sys.settings.CognitoIdentityUserPoolRegion,
            credentialsProvider: nil)
        
        let poolConfiguration = AWSCognitoIdentityUserPoolConfiguration(
            clientId: sys.settings.CognitoIdentityUserPoolAppClientId,
            clientSecret: sys.settings.CognitoIdentityUserPoolAppClientSecret,
            poolId: sys.settings.CognitoIdentityUserPoolId)
        
        AWSCognitoIdentityUserPool.register(
            with: serviceConfiguration,
            userPoolConfiguration: poolConfiguration,
            forKey: sys.settings.AWSCognitoUserPoolsSignInProviderKey)
        
        self.storyboard = UIStoryboard(name: "Main", bundle: nil)
        pool = AWSCognitoIdentityUserPool(forKey: sys.settings.AWSCognitoUserPoolsSignInProviderKey)
        pool?.delegate = self
        
        if !loadProfile() {
            sys.log("ProfileManager", text: "load profile failed\n")
        }

    }
    
    //=======================================================================
    // Standard sign in
    //=======================================================================
    func signIn(email: String?, password: String?) {
        if email != nil && password != nil {
            let authDetails = AWSCognitoIdentityPasswordAuthenticationDetails(username: email!,
                                                                              password: password! )
            self.passwordAuthenticationCompletion?.set(result: authDetails)
        }
        else {
            let alertController = UIAlertController(title: "Missing information",
                                                    message: "Please enter a valid user name and password",
                                                    preferredStyle: .alert)
            let retryAction = UIAlertAction(title: "Retry", style: .default, handler: nil)
            alertController.addAction(retryAction)
        }
    }
    
    //=======================================================================
    // Standard sign up
    //=======================================================================
    func signUp(email: String?, password: String?, phone: String?) {
        
        // Check invalid field
        guard let userNameValue = email, !userNameValue.isEmpty,
            let passwordValue = password, !passwordValue.isEmpty else {
                sys.showAlert(title: "Missing Required Fields",
                                        message: "Email / Password are required for registration.",
                                        prompt: "Ok")
                return
        }
        
        // Check valid email format
        guard isValidEmail(userNameValue) else {
            sys.showAlert(title: "Invalid email format",
                                    message: "Email ex: joe@gmail.com",
                                    prompt: "Ok")
            return
        }
        
        // Check valid phone number
        guard let phoneNumber = phone, isValidPhoneNumber(phoneNumber) else {
            sys.showAlert(title: "Invalid phone number format",
                                    message: "Phone ex: 512-913-4740",
                                    prompt: "Ok")
            return
        }
        
        var attributes = [AWSCognitoIdentityUserAttributeType]()
        
        if let phoneValue = phone, !phoneValue.isEmpty {
            let phoneField = AWSCognitoIdentityUserAttributeType()
            phoneField?.name = "phone_number"
            phoneField?.value = phoneValue
            attributes.append(phoneField!)
        }
        
        // Email is the username
        let emailField = AWSCognitoIdentityUserAttributeType()
        emailField?.name = "email"
        emailField?.value = userNameValue
        attributes.append(emailField!)
        
        
        //sign up the user
        newUsername = userNameValue
        pool? = AWSCognitoIdentityUserPool.init(forKey: sys.settings.AWSCognitoUserPoolsSignInProviderKey)
        pool?.signUp(userNameValue, password: passwordValue, userAttributes: attributes, validationData: nil).continueWith {[weak self] (task) -> Any? in
            guard self != nil else { return nil }
            
            DispatchQueue.main.async(execute: {
                if let error = task.error as NSError? {
                    self?.signUpDelegate?.signUpFailed(error)
                }
                else if let result = task.result  {
                    // handle the case where user has to confirm his identity via email / SMS
                    if (result.user.confirmedStatus != AWSCognitoIdentityUserStatus.confirmed) {
                        self?.signUpDelegate?.signUpConfirming(result.codeDeliveryDetails?.destination)
                    }
                    else {
                        self?.signUpDelegate?.signedUpAlready()
                    }
                }
                
            })
            return nil
        }
    }
    
    //=======================================================================
    // Get Facebook user info
    //=======================================================================
    func confirmSignUp(code: String?) {
        guard let confirmationCodeValue = code, !confirmationCodeValue.isEmpty else {
            sys.showAlert(title: "Confirmation code missing.",
                                    message: "Please enter a valid confirmation code.",
                                    prompt: "Ok")
            return
        }
        let newUser = self.pool?.getUser(newUsername)
        newUser?.confirmSignUp(code!, forceAliasCreation: true).continueWith {[weak self] (task: AWSTask) -> AnyObject? in
            DispatchQueue.main.async(execute: {
                if let error = task.error as NSError? {
                    self?.confirmSignUpDelegate?.signUpConfirmedFailed(error)
                }
                else {
                    self?.confirmSignUpDelegate?.signUpConfirmed()
                }
            })
            return nil
        }
    }
    
    //=======================================================================
    // Get Facebook user info
    //=======================================================================
    func resendConfirmationCode() {
        
        let newUser = self.pool?.getUser(newUsername)
        newUser?.resendConfirmationCode().continueWith {[weak self] (task: AWSTask) -> AnyObject? in
            guard let _ = self else { return nil }
            DispatchQueue.main.async(execute: {
                if let error = task.error as NSError? {
                    if let title = error.userInfo["__type"] as? String {
                        if let message = error.userInfo["message"] as? String {
                            sys.showAlert(title: title, message: message, prompt: "Ok")
                        }
                    }
                }
                else if let result = task.result {
                    sys.showAlert(title: "Code Resent",
                            message: "Code resent to \(result.codeDeliveryDetails?.destination! ?? " no message")",
                            prompt: "Ok")
                }
            })
            return nil
        }
    }
    
    //=======================================================================
    // Get Facebook user info
    //=======================================================================
    func requestNewPassword(email: String?) {
        guard let username = email, !username.isEmpty else {
            sys.showAlert(title: "Missing UserName",
                                    message: "Please enter a valid user name.",
                                    prompt: "Ok")
            return
        }
        self.user = self.pool?.getUser(username)
        self.user?.forgotPassword().continueWith{ [weak self] (task: AWSTask) -> AnyObject? in
            guard self != nil else {return nil}
            DispatchQueue.main.async(execute: {
                if let error = task.error as NSError? {
                    if let title = error.userInfo["__type"] as? String {
                        if let message = error.userInfo["message"] as? String {
                            sys.showAlert(title: title, message: message, prompt: "Ok")
                        }
                    }
                }
                else {
                    self?.forgotPasswordRequestDelegate?.forgotPasswordRequestSent()
                }
            })
            return nil
        }
    }
    
    //=======================================================================
    // Get Facebook user info
    //=======================================================================
    func confirmNewPassword(code: String?, password: String?) {
        
        guard let confirmationCodeValue = code, !confirmationCodeValue.isEmpty else {
            sys.showAlert(title: "Confirmation code is empty",
                                    message: "Please enter a valid confirmation code.",
                                    prompt: "Ok")
            return
        }
        
        guard let proposedPassword = password, !proposedPassword.isEmpty else {
            sys.showAlert(title: "Password Field Empty",
                                    message: "Please enter a password of your choice.",
                                    prompt: "Ok")
            return
        }
        
        self.user?.confirmForgotPassword(confirmationCodeValue, password: proposedPassword).continueWith {[weak self] (task: AWSTask) -> AnyObject? in
            DispatchQueue.main.async(execute: {
                if let error = task.error as NSError? {
                    self?.forgotPasswordConfirmDelegate?.forgotPasswordRequestConfirmFailed(error)
                }
                else {
                    self?.forgotPasswordConfirmDelegate?.forgotPasswordRequestConfirmed()
                }
            })
            return nil
        }
    }
    
    
    //=======================================================================
    // Handle Sign Up pressed
    //=======================================================================
    func isValidEmail(_ emailStr:String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: emailStr)
    }
    
    //=======================================================================
    // Handle Sign Up pressed
    //=======================================================================
    func isValidPhoneNumber(_ value: String) -> Bool {
        /*
        let phoneRegEx = "^\\d{3}-\\d{3}-\\d{4}$"
        let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegEx)
        let result =  phoneTest.evaluate(with: value)
        return result
        */
        return true
    }
    
    
    //=======================================================================
    // Check authentication
    //=======================================================================
    func checkAuthentication(_ completion: @escaping ()->Void) {
        pool = AWSCognitoIdentityUserPool(forKey: sys.settings.AWSCognitoUserPoolsSignInProviderKey)
        if (user == nil) {
            user = self.pool?.currentUser()
        }
    
        user?.getDetails().continueOnSuccessWith { [weak self] (task) -> AnyObject? in
            DispatchQueue.main.async(execute: {
                self?.response = task.result
                for attribute in (self?.response?.userAttributes)! {
                    if let value = attribute.value {
                        switch attribute.name {
                        case "sub":
                            self?.personal.sub = value
                            sys.log("ProfileManager", text: "user=\(value) logged in\n")
                        case "email_verified":
                            self?.personal.emailVerified = (value == "true")
                        case "phone_number_verified":
                            self?.personal.phoneNumberVerified = (value == "true")
                        case "phone_number":
                            self?.personal.phoneNumber = value
                        case "email":
                            self?.personal.email = value
                        default:
                            sys.log("ProfileManager", text: "unknown attribute=\(String(describing: attribute.name))\n")
                        } // switch
                    }
                }
                completion()
            })
            return nil
        }
    }
    
    //=======================================================================
    // Check authentication
    //=======================================================================
    func signOut() {
        if usingFacebook {
            fbLoginManager?.logOut()
            usingFacebook = false
            sys.log("ProfileManager", text: "Facebook logout.\n")
        }
        else {
            self.user?.signOut()
            self.response = nil
        }
        user?.getDetails().continueOnSuccessWith { [weak self] (task) -> AnyObject? in
            DispatchQueue.main.async(execute: {
                self?.response = task.result
            })
            return nil
        }
    }
    
    //=======================================================================
    // Initialize Facebook SDK - place it in
    //      func application(_ app: UIApplication, open url: URL,
    //          options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool
    // inside AppDelegate
    //=======================================================================
    func facebookInit(app: UIApplication, url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        let appId: String = sys.settings.fbAppId
        if url.scheme != nil && url.scheme!.hasPrefix("fb\(appId)") && url.host ==  "authorize" {
            return ApplicationDelegate.shared.application(app, open: url, options: options)
        }
        return false
    }
    
    //=======================================================================
    // Get Facebook user info - if login is successful, user info is copied
    // to Cognito and delegate fbSignInSuccedded() is called with
    // userInfo passed in as a NSDictionary
    //=======================================================================
    func facebookSignIn() {
        sys.log("ProfileManager", text: "Signing in via Facebook\n")
        fbLoginManager = LoginManager()
        fbLoginManager?.loginBehavior = LoginBehavior.browser
        fbLoginManager?.logIn(permissions: ["public_profile","email"], from: nil) { [weak self] (result, error) -> Void in
            if let error = error {
                self?.fbSignInDelegate?.fbSignInFailed(error)
            }
            else if let result = result, result.isCancelled {
                self?.fbSignInDelegate?.fbSignInCancelled()
            }
            else {
                let request = GraphRequest(graphPath: "me",
                                           parameters: ["fields": "id, first_name, last_name, email, picture"])
                request.start(completionHandler: { [weak self] (connection, result, error) -> Void in
                    if error == nil {
                        let userInfo = result as! NSDictionary
                        sys.log("ProfileManager", text: "User firstname=\(userInfo["first_name"]!)\n")
                        sys.log("ProfileManager", text: "User lastname=\(userInfo["last_name"]!)\n")
                        sys.log("ProfileManager", text: "User email=\(userInfo["email"]!)\n")
                        sys.log("ProfileManager", text: "User id=\(userInfo["id"]!)\n")
                        sys.log("ProfileManager", text: "User fbDetails=\(userInfo)\n")
                        self?.usingFacebook = true
                        self?.fbSignInDelegate?.fbSignInSucceeded(userInfo)
                        return
                    }
                    else {
                        sys.log("ProfileManager", text: "Facebook GraphRequest error=\(String(describing: error))\n")
                        sys.showAlert(title: "Facebook error",
                                                message: "User information request failed",
                                                prompt: "Ok")
                    }
                })
            }
        }
    }
    
    //=======================================================================
    // Facebook activate app - to place inside AppDelegate's
    // applicationDidBecomeActive() method
    // https://github.com/facebook/facebook-swift-sdk/issues/463#issuecomment-499367825
    //=======================================================================
    func facebookActivateApp() {
        sys.log("ProfileManager", text: "Facebook activeApp()\n")
        AppEvents.activateApp()
    }
    
    //==========================================================
    // Encode SensorData into JSON string
    //==========================================================
    func saveProfile() -> Bool {
        sys.log("ProfileManager", text: "Saving profile\n")
        let pathURL = URL(fileURLWithPath: sys.storage.root! + "/profile/profile.json")
        _ = sys.storage.removeItem(at: pathURL)
        if sys.storage.writeFile(fileURL: pathURL, text: jsonEncode(personal)) == false {
            sys.log("ProfileManager", text: "Profile save failed\n")
            return false
        }
        return true
    }
    
    //==========================================================
    // Load profile
    //==========================================================
    func loadProfile() -> Bool {
        sys.log("ProfileManager", text: "Loading profile\n")
        let pathURL = URL(fileURLWithPath: sys.storage.root! + "/profile/profile.json")
        let (success, text) = sys.storage.readFile(fileURL: pathURL)
        if success, let text = text, let data = jsonDecode(text) {
            sys.profile.personal = data
            return true
        }
        else {
            sys.log("ProfileManager", text: "Load profile failed\n")
            return false
        }
    }
    
    //==========================================================
    // Encode SensorData into JSON string
    //==========================================================
    func jsonEncode(_ data: PersonalData) -> String {
        let jsonData = try! JSONEncoder().encode(data)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        sys.log("ProfileManager", text: "jsonDecode encoded PersonalData to \(jsonString)\n")
        return jsonString
    }
    
    //==========================================================
    // Decode a JSON string into a SensorData
    //==========================================================
    func jsonDecode(_ string : String) -> PersonalData? {
        if let jsonData = string.data(using: .utf8) {
            let decoder = JSONDecoder()
            do {
                let report = try decoder.decode(PersonalData.self, from: jsonData)
                sys.log("ProfileManager", text: "jsonDecode success for \(string)\n")
                return report
            }
            catch {
                sys.log("ProfileManager", text: "jsonDecode failed error=\(error.localizedDescription)\n")
            }
        }
        return nil
    }
}


/////////////////////////////////////////////////////////////////////////
//  LoginViewController -AWSCognitoIdentityPasswordAuthentication
/////////////////////////////////////////////////////////////////////////
extension ProfileManager: AWSCognitoIdentityPasswordAuthentication {
    
    //=======================================================================
    // getDetails
    //=======================================================================
    public func getDetails(_ authenticationInput: AWSCognitoIdentityPasswordAuthenticationInput, passwordAuthenticationCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>) {
        self.passwordAuthenticationCompletion = passwordAuthenticationCompletionSource
    }
    
    //=======================================================================
    // didCompleteStepWithError
    //=======================================================================
    public func didCompleteStepWithError(_ error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let error = error as NSError? {
                self?.signInDelegate?.signInFailed(error)
            }
            else {
                self?.signInDelegate?.signInSucceeded()
            }
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////
// AWSCognitoIdentityInteractiveAuthenticationDelegate protocol delegate
////////////////////////////////////////////////////////////////////////////////////
extension ProfileManager: AWSCognitoIdentityInteractiveAuthenticationDelegate {
    
    // Return self that implements AWSCognitoIdentityPasswordAuthentication
    func startPasswordAuthentication() -> AWSCognitoIdentityPasswordAuthentication {
        
        sys.log("ProfileManager", text: "Start password authentication\n")
        
        if (self.navigationController == nil) {
            self.navigationController = self.storyboard?.instantiateViewController(withIdentifier: "loginController") as? UINavigationController
        }
        
        if (self.loginViewController == nil) {
            self.loginViewController = self.navigationController?.viewControllers[0] as? LoginViewController
        }
        
        DispatchQueue.main.async {
            
            sys.log("ProfileManager", text: "present LoginViewController\n")
            
            self.navigationController!.popToRootViewController(animated: true)
            if (!self.navigationController!.isViewLoaded
                || self.navigationController!.view.window == nil) {
                
                (UIApplication.shared.delegate as! AppDelegate).window?.rootViewController?.present(self.navigationController!,
                                                         animated: true,
                                                         completion: nil)
            }
        }
        return self
    }
}
