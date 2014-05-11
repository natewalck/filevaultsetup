//
//  FVSApplicationInstance.m
//  FileVault Setup
//
//  Created by Sam Marshall on 5/10/14.
//  Copyright (c) 2014 Simon Fraser Universty. All rights reserved.
//

#import "FVSApplicationInstance.h"
#import <DiskArbitration/DASession.h>
#import <IOKit/IOKitLib.h>

@implementation FVSApplicationInstance

+ (BOOL)runningAsRoot {
	return (getuid() == 0 ? YES : NO);
}

+ (int)setUserId:(uid_t)uid {
	return seteuid(uid);
}

+ (BOOL)rootVolumeIsEncrypted {
    CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR("/"), kCFURLPOSIXPathStyle, true);
    
    DASessionRef session = DASessionCreate(kCFAllocatorDefault);
    DADiskRef disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url);
    
    io_service_t diskService = DADiskCopyIOMedia(disk);
    CFTypeRef isEncrypted = IORegistryEntryCreateCFProperty(diskService, CFSTR("CoreStorage Encrypted"), kCFAllocatorDefault, 0);
    
    bool state = NO;
    if (isEncrypted) {
        state = CFBooleanGetValue(isEncrypted) ? YES : NO;
        CFRelease(isEncrypted);
    }
    
    CFRelease(disk);
    CFRelease(url);
    CFRelease(session);
    IOObjectRelease(diskService);
    
    return state;
}

+ (BOOL)valueForDefaultsKey:(NSString *)key {
	return [[[NSUserDefaults standardUserDefaults] valueForKeyPath:key] boolValue];
}

@end
