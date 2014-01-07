//
//  MountController.m
//  PreLoginMount
//
//  Created by Iliya Lindov on 12/27/13.
//
//

// TODO: Add verbose logging functionality and more informative status messages
// TODO: Memory management

#import "MountController.h"

@implementation MountController

NSDictionary *usersDataStructure;
NSDictionary *commonSettings;

- (void) awakeFromNib{
    NSArray *userNames;
    BOOL parameterFsckOnMount;
    NSDictionary *configuration = [[NSDictionary alloc] initWithContentsOfFile:@"/etc/PreLoginMount.plist"];
    
    usersDataStructure = [configuration objectForKey:@"Users"];
    commonSettings = [configuration objectForKey:@"Common"];
    userNames = [usersDataStructure allKeys];
    
    if(![userNames count]){
        NSString *messageText = @"Critical configuration error!";
        NSString *informativeText = @"Configuration file (/etc/PreLoginMount.plist) is missing or corrupt, or no users are defined.";
        NSAlert *alert = [[NSAlert alloc] init];
        
        NSLog(@"%@: %@", messageText, informativeText);
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:messageText];
        [alert setInformativeText:informativeText];
        [alert runModal];
        [NSApp terminate:self];
    }
    
    [usersList removeAllItems];
    for(NSString *name in userNames){
        [usersList addItemWithTitle:name];
    }
    
    parameterFsckOnMount = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"FsckOnMount"] boolValue];
    
    [spinner setDisplayedWhenStopped:NO];
    ((parameterFsckOnMount) ? [checkIntegrity setState:NSOnState] : [checkIntegrity setState:NSOffState]);
    [verboseMode setState:NSOffState];
    [statusField setObjectValue:@"Initialized..."];
}

- (IBAction)mountRequested:(id) __unused sender{
    // TODO: sanitize the password value - escape special chars
    
    [spinner startAnimation:self];
    if ([checkIntegrity state]){
        [statusField setObjectValue:@"Check and mount..."];
    }
    else {
        [statusField setObjectValue:@"Mounting..."];
    }
    
    [self attemptToMountWithPassword:[diskUnlockPassword objectValue]];
}

- (void)attemptToMountWithPassword:(NSString *)password {
    // NSLog(@"Path: '%@'; Password: '%@'\n", diskFilePath, password);
    
    NSString *parameterDiskImage = [[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"DiskImage"];
    NSString *parameterMountPoint = [[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"MountPoint"];
    BOOL parameterReadOnly = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"ReadOnly"] boolValue];
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
                              (([checkIntegrity state]) ? @"-autofsck" : @"-noautofsck"),
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
    
//
    NSTask *execution = [[NSTask alloc] init];
    
    [execution setLaunchPath:[commonSettings objectForKey:@"PathToSh"]];
    [execution setArguments:[[NSArray alloc] initWithObjects:@"-c", mountCommand, nil]];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperationWithBlock:^(void) {
        @try {
            [execution launch];
            [execution waitUntilExit];
        }
        @catch (NSException *exception) {
            NSLog(@"Exception - %@", [exception reason]);
        }

        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void){
            [self mountAttemptEndedWithStatus:[execution terminationStatus]];
        }];
    }];
}

- (void)mountAttemptEndedWithStatus:(NSInteger)status{
    NSLog(@"AAA: %ld", (long)status);
    if (!status){
        [NSApp terminate:self];
    }
    else {
        sleep(3);
        
        [statusField setObjectValue:@"Mount failed..."];
        [spinner stopAnimation:self];
    }
}

- (IBAction)showVerboseLog:(id) sender{
    
    NSLog(@"Verbose: %ld\n", [verboseMode state]);
    NSLog(@"Sender is: %@", [[sender window] class]);
}

@end
