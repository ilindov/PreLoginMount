//
//  MountController.m
//  PreLoginMount
//
//  Created by Iliya Lindov on 12/27/13.
//
//

// TODO: Memory management

#import "MountController.h"

@implementation MountController

NSString *configurationFile = @"/etc/PreLoginMount.plist";

NSDictionary *configuration;
NSDictionary *usersDataStructure;
NSDictionary *commonSettings;
NSMutableDictionary *metaSettings;
NSRect originalFrame;
NSRect resizedFrame;
NSRect resizedVerboseLogArea;

- (void) awakeFromNib{
    NSArray *userNames;
    BOOL parameterFsckOnMount;
    configuration = [[NSDictionary alloc] initWithContentsOfFile:configurationFile];
    
    usersDataStructure = [configuration objectForKey:@"Users"];
    commonSettings = [configuration objectForKey:@"Common"];
    metaSettings = [configuration objectForKey:@"Meta"];
    userNames = [[usersDataStructure allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
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
    
    [usersList selectItemWithTitle:[metaSettings objectForKey:@"LastUser"]];
    
    parameterFsckOnMount = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"FsckOnMount"] boolValue];
    
    [spinner setDisplayedWhenStopped:NO];
    ((parameterFsckOnMount) ? [checkIntegrity setState:NSOnState] : [checkIntegrity setState:NSOffState]);
    [verboseMode setState:NSOffState];
    
    [[verboseLogArea enclosingScrollView] setHidden:YES];
    [verboseLogArea setFont:[NSFont fontWithName:@"Courier" size:11]];
    
    [clearVerboseLogArea setHidden:YES];
    [closeAndContinueButton setHidden:YES];
    
    [statusField setObjectValue:@"Initialized..."];
}

- (IBAction)attemptToMountWithPassword:(id) __unused sender {
    // TODO: sanitize the password value - escape special chars
    NSPipe *standardOut;
    NSFileHandle *readHandle;

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
                                %@ \
                                -nokernel \
                                -noautoopen \
                                -owners %@ \
                                %@ \
                                \"%@\"",
                              ((parameterEncrypted) ? [[[[@"\"" stringByAppendingString:[commonSettings objectForKey:@"PathToPrintf"]]
                                    stringByAppendingString:@"\" '"]
                                    stringByAppendingString:password]
                                    stringByAppendingString:@"' | "] : @""),
                              [[@"\"" stringByAppendingString:[commonSettings objectForKey:@"PathToHdiutil"]] stringByAppendingString:@"\""],
                              ((parameterEncrypted) ? @"-stdinpass" : @""),
                              (([checkIntegrity state]) ? @"-autofsck" : @"-noautofsck"),
                              ((!parameterBrowseable) ? @"-nobrowse" : @""),
                              ((parameterReadOnly) ? @"-readonly" : @"-readwrite"),
                              ((parameterVerifyImage) ? @"-verify" : @"-noverify"),
                              ((parameterVerifyImage) ? ((parameterIgnoreBadChecksum) ? @"-ignorebadchecksums" : @"-noignorebadchecksums") : @""),
                              (([verboseMode state]) ? @"-verbose" : @""),
                              ((parameterHonorOwners) ? @"on" : @"off"),
                              (([parameterMountPoint length] > 0) ? [[@"-mountpoint \""
                                                                        stringByAppendingString:parameterMountPoint]
                                                                        stringByAppendingString:@"\""] : @""),
                              parameterDiskImage];
    
    // DELME!!!
    NSLog(@"CMD: '%@'\n", mountCommand);
    
    
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
    
    if ([verboseMode state]){
        standardOut = [[NSPipe alloc] init];
        readHandle = [standardOut fileHandleForReading];
        [execution setStandardOutput:standardOut];
        [execution setStandardError:standardOut];
    }
        
    [execution setLaunchPath:[commonSettings objectForKey:@"PathToSh"]];
    [execution setArguments:[[NSArray alloc] initWithObjects:@"-c", mountCommand, nil]];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperationWithBlock:^(void) {
        NSString *verboseText = nil;
        
        @try {
            [execution launch];
            [execution waitUntilExit];
            
            // TODO: Only if verbose mode enabled
            if([verboseMode state]){
                verboseText = [[NSString alloc] initWithData:[readHandle availableData] encoding:NSUTF8StringEncoding];
            }
            
            if ([execution terminationStatus])
                [NSThread sleepForTimeInterval:3.0];
        }
        @catch (NSException *exception) {
            NSLog(@"Exception - %@", [exception reason]);
        }

        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void){
            [self mountAttemptEndedWithStatus:[execution terminationStatus] verboseOutput:verboseText];
        }];
    }];
}

- (void)mountAttemptEndedWithStatus:(NSInteger)status verboseOutput:(NSString *)verboseText{
    [metaSettings setObject:[usersList titleOfSelectedItem] forKey:@"LastUser"];
    [configuration writeToFile:configurationFile atomically:YES];
    
    if ([verboseMode state]){
        NSLog(@"%@\n", verboseText);
        [verboseLogArea setString:@""];
        [verboseLogArea setString:verboseText];
    }
        
    if (!status && ![verboseMode state]){
        [NSApp terminate:self];
    }
    else if (!status && [verboseMode state]){
        [closeAndContinueButton setHidden:NO];
        [spinner stopAnimation:self];
        [statusField setObjectValue:@"Mounted successfully"];
        [clearVerboseLogArea setEnabled:NO];
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
    if (NSIsEmptyRect(originalFrame))
        originalFrame = [[sender window] frame];
    if (NSIsEmptyRect(resizedFrame)){
        CGFloat increaseBy = 150.0f;
        
        resizedFrame = originalFrame;
        resizedFrame.size.height += increaseBy;
        resizedFrame.origin.y -= increaseBy;
    }
    if (NSIsEmptyRect(resizedVerboseLogArea)){
        resizedVerboseLogArea = [[verboseLogArea enclosingScrollView] frame];
        resizedVerboseLogArea.origin.y = 18.0f;
        resizedVerboseLogArea.origin.x = 18.0f;
        resizedVerboseLogArea.size.height = 130.0f;
        resizedVerboseLogArea.size.width = resizedFrame.size.width - 18.0f*2;
    }
    
    if ([verboseMode state]){
    // increase window height
        [[sender window] setFrame:resizedFrame display:YES animate:YES];
        [[verboseLogArea enclosingScrollView] setHidden:NO];
        [clearVerboseLogArea setHidden:NO];
        [[verboseLogArea enclosingScrollView] setFrame:resizedVerboseLogArea];
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
}

- (IBAction)closeApplication:(id) __unused sender{
    [NSApp terminate:self];
}

@end
