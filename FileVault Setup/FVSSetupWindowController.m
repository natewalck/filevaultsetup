//
//  FVSSetupWindowController.m
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

#import "FVSSetupWindowController.h"
#import "FVSApplicationInstance.h"

@implementation FVSSetupWindowController

static int   numberOfShakes  = 4;
static float durationOfShake = 0.4f;
static float vigourOfShake   = 0.02f;

@synthesize password = _password;
@synthesize spinner  = _spinner;
@synthesize setup    = _setup;
@synthesize cancel   = _cancel;

- (id)init {
    self = [super initWithWindowNibName:@"FVSSetupWindowController"];
    
	if (self) {
		username = [[NSUserDefaults standardUserDefaults] objectForKey:FVSUsername];
		
		int result = [FVSApplicationInstance setUserId:0];
		if (!result == 0) {
			NSLog(@"Could not set UID, error: %i", result);
			// exit(result);
		}
	}
    
    return self;
}

// All credit to Matt Long
// This function was lifted directly from his awesome blog.
// http://www.cimgf.com/2008/02/27/core-animation-tutorial-window-shake-effect/
- (CAKeyframeAnimation *)shakeAnimation:(NSRect)frame {
    CAKeyframeAnimation *shakeAnimation = [CAKeyframeAnimation animation];
	
    CGMutablePathRef shakePath = CGPathCreateMutable();
    CGPathMoveToPoint(shakePath, NULL, NSMinX(frame), NSMinY(frame));
	int index;
	for (index = 0; index < numberOfShakes; ++index) {
		CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) - frame.size.width * vigourOfShake, NSMinY(frame));
		CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) + frame.size.width * vigourOfShake, NSMinY(frame));
	}
    CGPathCloseSubpath(shakePath);
    shakeAnimation.path = shakePath;
    shakeAnimation.duration = durationOfShake;
    CFRelease(shakePath);
	
    return shakeAnimation;
}

- (IBAction)setupAction:(NSButton *)sender {
    if ([self passwordMatch:[_password stringValue] forUsername:username]) {
        [self runFileVaultSetupForUser:username withPassword:[_password stringValue]];
    } else {
        // Shake it!
        [self harlemShake:@"Password Incorrect"];
    }
}

- (IBAction)cancelAction:(NSButton *)sender {
    [NSApp endSheet:[self window] returnCode:-1];
}

- (BOOL)passwordMatch:(NSString *)password forUsername:(NSString *)name {
    BOOL match = NO;
	ODSessionRef session = NULL;
	ODNodeRef node = NULL;
	ODRecordRef	rec = NULL;
    
    session = ODSessionCreate(NULL, NULL, NULL);
    node = ODNodeCreateWithNodeType(NULL, session, kODNodeTypeAuthentication, NULL);
    if (node) {
        rec = ODNodeCopyRecord(node, kODRecordTypeUsers, (__bridge CFStringRef)(name), NULL, NULL);
        
        if (rec) {
            match = ODRecordVerifyPassword(rec, (__bridge CFStringRef)(password), NULL);
            CFRelease(rec);
        }
        
        CFRelease(node);
    }

    CFRelease(session);
    return match;
}

- (void)harlemShake:(NSString *)message
{
    [_message setStringValue:message];
    [_sheet setAnimations:@{@"frameOrigin": [self shakeAnimation:[_sheet frame]]}];
	[[_sheet animator] setFrameOrigin:[_sheet frame].origin];
}

- (void)runFileVaultSetupForUser:(NSString *)name withPassword:(NSString *)passwordString {
    BOOL fvsRotatePrk = [FVSApplicationInstance valueForDefaultsKey:FVSRotatePRK];
	BOOL fvsCreateRecovery = [FVSApplicationInstance valueForDefaultsKey:FVSCreateRecoveryKey];
	BOOL fvsUseKeychain = [FVSApplicationInstance valueForDefaultsKey:FVSUseKeychain];
	
    // UI Setup
    [_setup setEnabled:NO];
    [_cancel setEnabled:NO];
    [_message setStringValue:@"Running..."];
    [_spinner startAnimation:self];

    // Setup Task args
    NSMutableArray *task_args;
    if (fvsRotatePrk && fvsCreateRecovery) {
        task_args = [@[@"changerecovery", @"-personal", @"-outputplist", @"-inputplist"] mutableCopy];
	}
	else {
        task_args = [@[@"enable", @"-outputplist", @"-inputplist"] mutableCopy];
        
        if (!fvsCreateRecovery) {
			[task_args insertObject:@"-norecoverykey" atIndex:1];
        }
        
        if (fvsUseKeychain) {
            [task_args insertObject:@"-keychain" atIndex:1];
        }
    }
    
    // Property List Out
    NSString *outputFile = @"/private/var/root/fdesetup_output.plist";
    BOOL outputFileCreateResult = [[NSFileManager defaultManager] createFileAtPath:outputFile contents:nil attributes:nil];
	if (outputFileCreateResult) {
		NSFileHandle *outHandle = [NSFileHandle fileHandleForWritingAtPath:outputFile];
		
		// The Property List for Input
		NSDictionary *input = @{ @"Username" : name, @"Password" : passwordString };
		
		// Task Setup
		NSTask *theTask = [[NSTask alloc] init];
		[theTask setLaunchPath:@"/usr/bin/fdesetup"];
		[theTask setArguments:task_args];
		[theTask setStandardOutput:outHandle];
		
		NSPipe *errorPipe = [NSPipe pipe];
		[theTask setStandardError:errorPipe];
		
		NSPipe *inputPipe = [NSPipe pipe];
		[theTask setStandardInput:inputPipe];
		NSFileHandle *writeHandle = [inputPipe fileHandleForWriting];
		
		// Task Run
		[theTask launch];
		
		// Task Input
		NSData *data = [NSPropertyListSerialization dataFromPropertyList:input format:NSPropertyListBinaryFormat_v1_0 errorDescription:nil];
		
		[writeHandle writeData:data];
		[writeHandle closeFile];
		
		// Task Error
		NSString *error = [[NSString alloc] initWithData:[[errorPipe fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
		
		// If the last char of error is a newline, remove it
		if ([error characterAtIndex:[error length] -1] == NSNewlineCharacter) {
			error = [error substringToIndex:[error length] -1];
		}
		
		// Clean up
		[theTask waitUntilExit];
		
		// Close
		int result = [theTask terminationStatus];
		[self setSetupError:error];
		
		[NSApp endSheet:[self window] returnCode:result];
	}
}

- (void)dealloc {
	uid_t userId = [[[NSUserDefaults standardUserDefaults] objectForKey:FVSUid] intValue];
    int result = [FVSApplicationInstance setUserId:userId];

    if (!result == 0) {
        NSLog(@"Could not set UID, error: %i", result);
        exit(result);
    }
}

@end
