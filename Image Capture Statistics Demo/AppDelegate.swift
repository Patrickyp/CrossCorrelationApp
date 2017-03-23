//
//  AppDelegate.swift
//  Image Capture Statistics Demo
//
//  Created by Patrick Pan on 11/28/16.
//  Copyright © 2016 3srm. All rights reserved.
//

import UIKit
import SwiftyDropbox

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // Initialize a dropbox session
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        /*
        // Override point for customization after application launch.
        let appKey = "4x70cov0ywjobdq"
        let appSecret = "1y5848488gvsih9"
        
        //create a new dropbox session, kDBRootAppFolder: Use it to access the app’s own folder only.
        let dropboxSession = DBSession(appKey: appKey, appSecret: appSecret, root: kDBRootAppFolder)
        DBSession.setShared(dropboxSession)
        */
        
        DropboxClientsManager.setupWithAppKey("ghmxni2jsfi1scb")
        
        return true
    }
    
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if let authResult = DropboxClientsManager.handleRedirectURL(url){
            switch authResult {
            case .success:
                print("Success! User is logged into Dropbox.")
                let loggedInNotification = NSNotification(name: NSNotification.Name(rawValue: "didLinkToDropboxAccountNotification"), object: nil)
                NotificationCenter.default.post(loggedInNotification as Notification)
            case .cancel:
                print("User manually canceled.")
            case .error(_, let description):
                print("Error: \(description)")
            }
        }
        return true
    }
    /*
    // The method will allow the authentication flow to be completed properly. No matter how the user will sign in, he is going to be able to
    // return back to the app now without any problems at all
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        if DBSession.shared().handleOpen(url) {
            if DBSession.shared().isLinked(){
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "didLinkToDropboxAccountNotification"), object: nil)
                return true
            }
        }
        return false
    }
    */
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    

}

