//
//  FVSAppDelegate.h
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

#import <Cocoa/Cocoa.h>
#import "FVSSetupWindowController.h"
#import "FVSConstants.h"
#import "FVSSetupControllerDelegate.h"

@interface FVSAppDelegate : NSObject <NSApplicationDelegate, FVSSetupControllerDelegate> {
    FVSSetupWindowController *setupController;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *instruct;
@property (nonatomic) id<FVSSetupControllerDelegate> setupDelegate;

- (IBAction)showSetupSheet:(id)sender;
- (IBAction)didEndSetupSheet:(id)sender returnCode:(int)result;

- (void)setupDidEndWithError:(NSAlert *)alert;
- (void)setupDidEndWithSuccess:(NSAlert *)alert;
- (void)setupDidEndWithAlreadyEnabled:(NSAlert *)alert;
- (void)setupDidEndWithNotRoot:(NSAlert *)alert;

- (void)restart;
- (IBAction)enable:(id)sender;
- (IBAction)noEnable:(id)sender;

@end
