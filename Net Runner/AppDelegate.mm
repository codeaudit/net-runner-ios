//
//  AppDelegate.m
//  Net Runner
//
//  Created by Philip Dow on 7/26/18.
//  Copyright © 2018 doc.ai (http://doc.ai)
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "AppDelegate.h"

#import "UserDefaults.h"

@import TensorIO;

@interface AppDelegate ()

@end

@implementation AppDelegate

/*!
 @abstract Returns path to the directory of models presented to Net Runner at build time
 @discussion The models at this path are copied over to the modelsPath and loaded from there
 when the application is run. Apart from the first time that Net Runner is launched, the
 models in this directory are not used.
 */
- (NSString*) initialModelsPath {
    return [[NSBundle mainBundle] pathForResource:@"models" ofType:nil];
}

/*!
 @abstract Returns path to the directory from which Net Runner loads models at run time
 @discussion Net Runner only loads models from this directory when it is launched.
 */
- (NSString*) modelsPath {
    NSURL *documentDirectoryURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains: NSUserDomainMask][0];
    NSString *documentDirectoryPath = [documentDirectoryURL path];
    NSString *modelsPath = [documentDirectoryPath stringByAppendingPathComponent:@"models"];
    return modelsPath;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    assert( sizeof(float_t) == 4 );
    
    // Move model bundles into Documents/models/ directory and then load them
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *modelsPath = [self modelsPath];
    NSError *error;
    
    // For Build 7, in case user installed previous models with build 6, clean the models directory
    
    if ( ![NSUserDefaults.standardUserDefaults boolForKey:kPrefsBuild7CleanedModelsDir] ) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:kPrefsBuild7CleanedModelsDir];
        if ( [fileManager fileExistsAtPath:modelsPath] ) {
            NSError *removeError;
            if ( ![fileManager removeItemAtPath:modelsPath error:&removeError] ) {
                NSLog(@"Error deleting file at path %@, error %@", modelsPath, removeError);
            }
        }
    }
    
    // Copy models from app bundle to documents irectory
    
    if (![fileManager fileExistsAtPath:modelsPath]) {
        NSLog(@"Loading packaged models into modelsPath: %@", modelsPath);
        BOOL copySuccess = [fileManager copyItemAtPath:[self initialModelsPath] toPath:modelsPath error:&error];
        if (!copySuccess) {
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    } else {
        NSLog(@"File/directory already exists at modelsPath: %@", modelsPath);
    }
    
    if ( ![TIOModelBundleManager.sharedManager loadModelBundlesAtPath:modelsPath error:&error] ) {
        NSLog(@"Unable to load model bundles at path %@", modelsPath);
    }
    
    // Register Defaults
    
    [NSUserDefaults.standardUserDefaults registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"UserDefaults" ofType:@"plist"]]];
    
    // Ensure that the select model is available, and if it is not, default to an included mobilenet model
    
    NSString *modelId = [NSUserDefaults.standardUserDefaults stringForKey:kPrefsSelectedModelID];
    TIOModelBundle *bundle = [TIOModelBundleManager.sharedManager bundleWithId:modelId];
    
    if ( bundle == nil ) {
        [NSUserDefaults.standardUserDefaults setObject:kPresDefaultModelID forKey:kPrefsSelectedModelID];
    }
    
    // Kick off application
    
    UIViewController *vc;
    
    #ifdef HEADLESS
        NSLog(@"Running application in headless mode");
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Headless" bundle:[NSBundle mainBundle]];
        vc = [storyboard instantiateInitialViewController];
    #else
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
        vc = [storyboard instantiateInitialViewController];
    #endif
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    
    UIApplication.sharedApplication.idleTimerDisabled = NO;
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    UIApplication.sharedApplication.idleTimerDisabled = YES;
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
