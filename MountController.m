//
//  MountController.m
//  PreLoginMount
//
//  Created by Iliya Lindov on 12/27/13.
//
//

// TODO: Add verbose logging functionality and more informative status messages
// TODO: To be able to mount without mountPoint, i.e. in /Volumes

#import "MountController.h"

@implementation MountController

NSDictionary *usersDataStructure;
NSDictionary *commonSettings;

- (void) awakeFromNib{
    [usersList removeAllItems];
    
    NSDictionary *configuration = [[NSDictionary alloc] initWithContentsOfFile:@"/etc/PreLoginMount.plist"];
    // NSLog(@"%@\n", configuration);
    
    usersDataStructure = [configuration objectForKey:@"Users"];
    commonSettings = [configuration objectForKey:@"Common"];
    
    NSArray *userNames = [usersDataStructure allKeys];
    
    // TODO: Fail if array elements are 0
    
    for(NSString *name in userNames){
        [usersList addItemWithTitle:name];
    }
    
    [statusField setObjectValue:@"Initialized..."];
}

- (IBAction)mountRequested:(id)sender{
    // TODO: sanitize the password value - escape special chars
    [statusField setObjectValue:@"Checking disk and mounting..."];
    
    BOOL result = [self attemptToMountWithPassword:[diskUnlockPassword objectValue]];
    
    if (result){
        [NSApp terminate:self];
    }
    else {
        // TODO: sleep 3s.
        [statusField setObjectValue:@"Mount failed..."];
    }
}

// HINT: hdiutil attach -verbose -stdinpass -autofsck -nobrowse -owners on -mountpoint /Users/ilia ~/Desktop/test.sparsebundle

- (BOOL)attemptToMountWithPassword:(NSString *)password {
    // NSLog(@"Path: '%@'; Password: '%@'\n", diskFilePath, password);
    
    NSString *parameterDiskImage = [[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"DiskImage"];
    NSString *parameterMountPoint = [[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"MountPoint"];
    BOOL parameterReadOnly = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"ReadOnly"] boolValue];
    BOOL parameterFsckOnMount = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"FsckOnMount"] boolValue];
    BOOL parameterVerifyImage = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"VerifyImage"] boolValue];
    BOOL parameterIgnoreBadChecksum = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"IgnoreBadChecksum"] boolValue];
    BOOL parameterBrowseable = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"Browseable"] boolValue];
    BOOL parameterHonorOwners = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"HonorOwners"] boolValue];
    BOOL parameterEncrypted = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"Encrypted"] boolValue];
    
    
    NSString *mountCommand = [NSString stringWithFormat:@"%@ %@ attach \
                                %@ \
                                %@ \
                                %@ \
                                %@ \
                                %@ \
                                %@ \
                                -nokernel \
                                -noautoopen \
                                -owners %@ \
                                %@ \
                                \"%@\"",
                              ((parameterEncrypted) ? [[[[@"\"" stringByAppendingString:[commonSettings objectForKey:@"PathToPrintf"]]
                                    stringByAppendingString:@"\" \""]
                                    stringByAppendingString:password]
                                    stringByAppendingString:@"\" | "] : @""),
                              [[@"\"" stringByAppendingString:[commonSettings objectForKey:@"PathToHdiutil"]] stringByAppendingString:@"\""],
                              ((parameterEncrypted) ? @"-stdinpass" : @""),
                              ((parameterFsckOnMount) ? @"-autofsck" : @"-noautofsck"),
                              ((!parameterBrowseable) ? @"-nobrowse" : @""),
                              ((parameterReadOnly) ? @"-readonly" : @"-readwrite"),
                              ((parameterVerifyImage) ? @"-verify" : @"-noverify"),
                              ((parameterVerifyImage) ? ((parameterIgnoreBadChecksum) ? @"-ignorebadchecksums" : @"-noignorebadchecksums") : @""),
                              ((parameterHonorOwners) ? @"on" : @"off"),
                              (([parameterMountPoint length] > 0) ? [[@"-mountpoint \""
                                                                        stringByAppendingString:parameterMountPoint]
                                                                        stringByAppendingString:@"\""] : @""),
                              parameterDiskImage];
    
    // NSLog(@"Command: %@\n", mountCommand);
    
    @try {
        
        NSTask *execution = [[NSTask alloc] init];
        [execution setLaunchPath:[commonSettings objectForKey:@"PathToSh"]];
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
