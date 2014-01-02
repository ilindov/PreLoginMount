//
//  MountController.m
//  PreLoginMount
//
//  Created by Iliya Lindov on 12/27/13.
//
//

// TODO: Add verbose logging functionality
// TODO: To be able to mount without mountPoint, i.e. in /Volumes

// HINT: hdiutil attach -verbose -stdinpass -autofsck -nobrowse -owners on -mountpoint /Users/ilia ~/Desktop/test.sparsebundle

#import "MountController.h"

@implementation MountController

NSDictionary *usersDataStructure;

- (void) awakeFromNib{
    [usersList removeAllItems];
    
    NSDictionary *configuration = [[NSDictionary alloc] initWithContentsOfFile:@"/etc/PreLoginMount.plist"];
    // NSLog(@"%@\n", configuration);
    
    usersDataStructure = [configuration objectForKey:@"Users"];
    NSArray *userNames = [usersDataStructure allKeys];
    
    // TODO: Fail if array elements are 0
    
    for(NSString *name in userNames){
        [usersList addItemWithTitle:name];
    }
    
    [statusField setObjectValue:@"Initialized..."];
}

- (IBAction)mountRequested:(id)sender{
    // TODO: sanitize the password value - escape special chars
    [statusField setObjectValue:@"Attempting to mount..."];
    
    NSString *diskFilePath = [[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"DiskImage"];
    NSString *mountPoint = [[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"MountPoint"];
    BOOL autoFsck = [[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"FsckOnMount"];
    
    BOOL result = [self attemptToMount:diskFilePath
                          withPassword:[diskUnlockPassword objectValue]
                            mountPoint:mountPoint
                              autoFsck:autoFsck];
    
    if (result){
        [NSApp terminate:self];
    }
    else {
        // TODO: sleep 3s.
        [statusField setObjectValue:@"Mount failed..."];
    }
}

- (BOOL)attemptToMount:(NSString *)diskFilePath
          withPassword:(NSString *)password
            mountPoint:(NSString *)mountPoint
              autoFsck:(BOOL)autoFsck {
    // NSLog(@"Path: '%@'; Password: '%@'\n", diskFilePath, password);
    NSString *mountCommand = [NSString stringWithFormat:@"/usr/bin/printf '%@' | /usr/bin/hdiutil attach -noverify %@ -mountpoint %@ -stdinpass %@", password, ((autoFsck) ? @"-autofsck" : @"-noautofsck"), mountPoint, diskFilePath];
    
    // NSLog(@"Command: %@\n", mountCommand);
    
    @try {
        
        NSTask *execution = [[NSTask alloc] init];
        [execution setLaunchPath:@"/bin/bash"];
        [execution setArguments:[[NSArray alloc] initWithObjects:@"-c", mountCommand, nil]];
        [execution launch];
        [execution waitUntilExit];
        // NSLog(@"Status: %d\n", [execution terminationStatus]);
        if (![execution terminationStatus])
            return YES;
    }
    @catch (NSException *exception) {
        NSLog(@"Exception - %@", [exception reason]);
    }

    return NO;
}

@end
