//
//  FVSAppDelegate.m
//  FileVault Setup
//
//  Created by Brian Warsing on 2013-03-05.

/*
 * Copyright (c) 2013 Simon Fraser Universty. All rights reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FVSAppDelegate.h"
#include <SystemConfiguration/SystemConfiguration.h>
#include <IOKit/IOKitLib.h>
#include <DiskArbitration/DASession.h>
#import "FVSApplicationInstance.h"

NSString * const FVSDoNotAskForSetup     = @"FVSDoNotAskForSetup";
NSString * const FVSForceSetup           = @"FVSForceSetup";
NSString * const FVSUseKeychain          = @"FVSUseKeychain";
NSString * const FVSCreateRecoveryKey    = @"FVSCreateRecoveryKey";
NSString * const FVSRotatePRK            = @"FVSRotatePRK";
NSString * const FVSUsername             = @"FVSUsername";
NSString * const FVSUid                  = @"FVSUid";

@implementation FVSAppDelegate

+ (void)initialize {
    // Grab the username and the uid of the Console user
    uid_t uid;
    NSString *username = CFBridgingRelease(SCDynamicStoreCopyConsoleUser(NULL, &uid, NULL));
    
    // UID Switcheroo
    // If the app is run using a loginhook, it will have UID 0, but we want
    // to use the NSUserDefaults for the Console user. Setting the Effective
    // UID for the process allows us to run the app as the user.
    int result = [FVSApplicationInstance setUserId:uid];
    
    if (!result == 0) {
        NSLog(@"Could not set UID, error: %i", result);
        exit(result);
    }
    
    // Register defaults
	NSDictionary *defaultValues = @{FVSUid: @(uid),
									FVSUsername: username,
									FVSRotatePRK: @(NO),
									FVSCreateRecoveryKey: @(YES),
									FVSUseKeychain: @(YES),
									FVSForceSetup: @(NO),
									FVSDoNotAskForSetup: @(NO)};
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
    
    // Establish the startup mode
    // Are we root? If so, exit if the root vol already encrypted.
    // Also, hide the menu bar.
    // Is this a forced setup? If not, respect that the user has
    // opted out, and simply exit.
    if ([FVSApplicationInstance runningAsRoot]) {
        BOOL fvsrotateprk = [FVSApplicationInstance valueForDefaultsKey:FVSRotatePRK];
        if ([FVSApplicationInstance rootVolumeIsEncrypted] && !fvsrotateprk) {
            exit(0);
        }
        [NSMenu setMenuBarVisible:NO];
        if (![FVSApplicationInstance valueForDefaultsKey:FVSForceSetup]) {
            if ([FVSApplicationInstance valueForDefaultsKey:FVSDoNotAskForSetup]) {
                exit(0);
            }
        }
    }
}

- (IBAction)showSetupSheet:(id)sender {
    if (!setupController) {
        setupController = [[FVSSetupWindowController alloc] init];
    }
    
    [NSApp beginSheet:[setupController window] modalForWindow:_window modalDelegate:self didEndSelector:@selector(didEndSetupSheet:returnCode:) contextInfo:NULL];
}

- (IBAction)didEndSetupSheet:(id)sender returnCode:(int)result
{
    // Error
    NSString *error = [setupController setupError];
	
    [NSApp endSheet:[setupController window]];
    [[setupController window] orderOut:sender];
    setupController = nil;
    
    // Basic Alert
    NSAlert *alert = [[NSAlert alloc] init];
    SEL theSelector = @selector(setupDidEndWithError:);
    
    // What kind of alert?
    if (result == -1) {
        // Cancelled
        NSLog(@"User canceled operation");
    } else if (result == 0) {
        // Success
        theSelector = @selector(setupDidEndWithSuccess:);
        [alert setMessageText:@"Restart Required"];
        [alert setInformativeText:@"Click OK to restart and complete the setup."];
    } else {
        // Failure
        [alert setAlertStyle:NSCriticalAlertStyle];
		[alert setMessageText:@"FileVault Setup Error"];
		[alert setInformativeText:[error stringByAppendingString:[NSString stringWithFormat:@" [%d]", result]]];
    }
    
    // Only alert on error or success, not on cancel
    if (result > -1) {
        NSLog(@"%@ [%d]", error, result);
        [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:theSelector contextInfo:nil];
    }
    
}

- (void)setupDidEndWithError:(NSAlert *)alert {
    NSLog(@"Setup encountered an error.");
}

- (void)setupDidEndWithSuccess:(NSAlert *)alert {
    NSLog(@"Setup complete. Restarting...");
    [_window orderOut:self];
    [self restart];
}

- (void)setupDidEndWithAlreadyEnabled:(NSAlert *)alert {
    NSLog(@"FileVault is already enabled.");
    [_window close];
}

- (void)setupDidEndWithNotRoot:(NSAlert *)alert {
    NSLog(@"You must be an administrator to enable FileVault.");
    [_window close];
}

- (void)restart
{
    [NSThread sleepForTimeInterval:10];
    // UID Switcheroo
    int switcheroo = [FVSApplicationInstance setUserId:0];
    
    if (!switcheroo == 0) {
        NSLog(@"Could not set UID, error: %i", switcheroo);
    }
    
    // Task Setup
    NSTask *theTask = [[NSTask alloc] init];
    [theTask setLaunchPath:@"/sbin/reboot"];
    
    // Task Run
    [theTask launch];
    
    // UID Switcheroo
	uid_t filevaultUserId = [[[NSUserDefaults standardUserDefaults] objectForKey:FVSUid] intValue];
    [FVSApplicationInstance setUserId:filevaultUserId];
	
    [_window close];
}

- (IBAction)enable:(id)sender {    
    // Are we running as root?
    if ([FVSApplicationInstance runningAsRoot]) {
        NSString *info = @"FileVault will be enabled at your next login.";
        // ALERT
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Requires Logout"];
        [alert setInformativeText:info];
        [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(setupDidEndWithNotRoot:) contextInfo:nil];
    }
    [self showSetupSheet:nil];
}

- (IBAction)noEnable:(id)sender {
    [_window close];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	_setupDelegate = self;
    // Insert code here to initialize your application
    BOOL forcedSetup = [FVSApplicationInstance valueForDefaultsKey:FVSForceSetup];
    
    if (forcedSetup) {
        [_instruct setFont:[NSFont fontWithName:@"Lucida Grande Bold" size:13.0]];
        [_instruct setStringValue:@"Policy set by your administrator requires that you activate FileVault before you can login to this workstation. Please click the enable button to continue."];
    }
    
    // Setup the main window
    // Are we running as root?
    if ([FVSApplicationInstance runningAsRoot]) {
        [_window makeKeyAndOrderFront:NSApp];
        [_window setCanBecomeVisibleWithoutLogin:YES];
        [_window setLevel:2147483631];
        [_window orderFrontRegardless];
        [_window makeKeyWindow];
        [_window becomeMainWindow];
    }
    [_window center];
    
    // Is FileVault enabled?
    BOOL fvstate = [FVSApplicationInstance rootVolumeIsEncrypted];
    BOOL fvsrotateprk = [FVSApplicationInstance valueForDefaultsKey:FVSRotatePRK];
    
    if (fvstate == YES && fvsrotateprk == NO) {
        // ALERT
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Already Enabled"];
        [alert setInformativeText:@"FileVault has already been enabled."];
        [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(setupDidEndWithAlreadyEnabled:) contextInfo:nil];
    }
}

@end
