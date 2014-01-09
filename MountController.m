//
//  MountController.m
//  PreLoginMount
//
//  Created by Iliya Lindov on 12/27/13.
//
//

// TODO: Add verbose logging functionality and more informative status messages
// TODO: Memory management
// TODO: User names sorting
// TODO: Remember last selected user

#import "MountController.h"

@implementation MountController

NSDictionary *usersDataStructure;
NSDictionary *commonSettings;
NSRect originalFrame;
NSRect resizedFrame;

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
    
    [[verboseLogArea enclosingScrollView] setHidden:YES];
    [clearVerboseLogArea setHidden:YES];
    
    [statusField setObjectValue:@"Initialized..."];
}

- (IBAction)attemptToMountWithPassword:(id) __unused sender {
    // TODO: sanitize the password value - escape special chars
    NSString *password = [diskUnlockPassword objectValue];
    
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
    
    NSTask *execution = [[NSTask alloc] init];
    
    [checkIntegrity setEnabled:NO];
    [verboseMode setEnabled:NO];
    [usersList setEnabled:NO];
    [diskUnlockPassword setEnabled:NO];
    [mountButton setEnabled:NO];
    [spinner startAnimation:self];
    if ([checkIntegrity state]){
        [statusField setObjectValue:@"Check and mount..."];
    }
    else {
        [statusField setObjectValue:@"Mounting..."];
    }
    
    [execution setLaunchPath:[commonSettings objectForKey:@"PathToSh"]];
    [execution setArguments:[[NSArray alloc] initWithObjects:@"-c", mountCommand, nil]];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperationWithBlock:^(void) {
        @try {
            [execution launch];
            [execution waitUntilExit];
            if ([execution terminationStatus])
                [NSThread sleepForTimeInterval:3.0];
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
    if (!status){
        [NSApp terminate:self];
    }
    else {
        [checkIntegrity setEnabled:YES];
        [verboseMode setEnabled:YES];
        [usersList setEnabled:YES];
        [diskUnlockPassword setEnabled:YES];
        [statusField setObjectValue:@"Mount failed..."];
        [spinner stopAnimation:self];
        [mountButton setEnabled:YES];
    }
}

- (IBAction)showVerboseLog:(id) sender{
    if(NSIsEmptyRect(originalFrame))
        originalFrame = [[sender window] frame];
    if(NSIsEmptyRect(resizedFrame)){
        CGFloat increaseBy = 150.0f;
        
        resizedFrame = originalFrame;
        resizedFrame.size.height += increaseBy;
        resizedFrame.origin.y -= increaseBy;
    }
    
    if ([verboseMode state]){
    // increase window height
        [[sender window] setFrame:resizedFrame display:YES animate:YES];
        [[verboseLogArea enclosingScrollView] setHidden:NO];
        [clearVerboseLogArea setHidden:NO];
        NSRect verboseLogAreaFrame = [[verboseLogArea enclosingScrollView] frame];
        verboseLogAreaFrame.origin.y = 18.0f;
        verboseLogAreaFrame.origin.x = 18.0f;
        verboseLogAreaFrame.size.height = 130.0f;
        verboseLogAreaFrame.size.width = resizedFrame.size.width - 18.0f*2;
        [[verboseLogArea enclosingScrollView] setFrame:verboseLogAreaFrame];
    }
    else {
    // put back the window height to the original value
        [[verboseLogArea enclosingScrollView] setHidden:YES];
        [[sender window] setFrame:originalFrame display:YES animate:YES];
        [clearVerboseLogArea setHidden:YES];
    }
}

- (IBAction)clearVerboseLog:(id) __unused sender{
    [verboseLogArea setString:@""];
    [verboseLogArea insertText:@"qqqqq"];
    [verboseLogArea insertNewline:nil];
    [verboseLogArea insertText:@";;;;;"];
}

@end
