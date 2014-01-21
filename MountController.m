//
//  MountController.m
//  PreLoginMount
//
//  Created by Iliya Lindov on 12/27/13.
//
//

#import "MountController.h"

@implementation MountController

NSString *configurationFile = @"/etc/PreLoginMount.plist";

NSDictionary *configuration;
NSMutableDictionary *usersDataStructure;
NSDictionary *commonSettings;
NSMutableDictionary *metaSettings;
NSRect originalFrame;
NSRect resizedFrame;
NSRect resizedVerboseLogArea;

// Initilize the NSPanel
- (void) awakeFromNib{
    NSArray *userNames;
    BOOL parameterFsckOnMount;
    BOOL parameterVerboseMode;
    
    // Load configuration from plist file
    configuration = [[NSDictionary alloc] initWithContentsOfFile:configurationFile];
    usersDataStructure = [configuration objectForKey:@"Users"];
    commonSettings = [configuration objectForKey:@"Common"];
    metaSettings = [configuration objectForKey:@"Meta"];
    
    // Generate array of user names to fill the users pop-up button
    userNames = [[usersDataStructure allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    // Check if configuration is OK
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
    
    [[verboseLogArea enclosingScrollView] setHidden:YES];
    [clearVerboseLogArea setHidden:YES];
    [closeAndContinueButton setHidden:YES];
    [spinner setDisplayedWhenStopped:NO];
    [statusField setObjectValue:@"Initialized..."];
    
    parameterFsckOnMount = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"FsckOnMount"] boolValue];
    ((parameterFsckOnMount) ? [checkIntegrity setState:NSOnState] : [checkIntegrity setState:NSOffState]);
    
    parameterVerboseMode = [[[usersDataStructure objectForKey:[usersList titleOfSelectedItem]] objectForKey:@"VerboseMode"] boolValue];
    if (parameterVerboseMode){
        [verboseMode setState:NSOnState];
        [self showVerboseLog:verboseMode];
    }
    else {
        [verboseMode setState:NSOffState];
    }
}

- (IBAction)attemptToMountWithPassword:(id) __unused sender {
    NSPipe *taskOutput;
    NSFileHandle *readHandle;

    NSString *password = [self sanitizePassword:[diskUnlockPassword objectValue]];
    
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
                              (([verboseMode state]) ? @"-verbose" : @""),
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
    
    // Use the verobose text view only if verbose mode is selected
    if ([verboseMode state]){
        [verboseLogArea setString:@""];
        taskOutput = [[NSPipe alloc] init];
        readHandle = [taskOutput fileHandleForReading];
        [execution setStandardOutput:taskOutput];
        [execution setStandardError:taskOutput];
    }
        
    [execution setLaunchPath:[commonSettings objectForKey:@"PathToSh"]];
    [execution setArguments:[[NSArray alloc] initWithObjects:@"-c", mountCommand, nil]];
    
    // Execute in a background thread
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperationWithBlock:^(void) {
        @try {
            [execution launch];
            
            if ([verboseMode state]){
                NSData *pipeContents;
                
                while ([pipeContents=[readHandle availableData] length]){
                    if (![execution isRunning])
                        break;
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^(void){
                        [self updateVerboseLogArea:[[NSString alloc] initWithData:pipeContents encoding:NSUTF8StringEncoding]];
                    }];
                }
            }
            else {
                [execution waitUntilExit];
            }

            // Wait for 3 secs if wrong pass is entered (or some other error occured)
            if ([execution terminationStatus])
                [NSThread sleepForTimeInterval:3.0];
        }
        @catch (NSException *exception) {
            NSLog(@"Exception - %@", [exception reason]);
        }

        // Update UI from the main thread
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void){
            [self mountAttemptEndedWithStatus:[execution terminationStatus]];
        }];
    }];
}

- (void)updateVerboseLogArea:(NSString *)textChunk{
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObject:[NSFont fontWithName:@"Courier" size:11] forKey:NSFontAttributeName];
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithString:textChunk attributes:textAttributes];
    
    NSLog(@"%@\n", textChunk);
    
    [[verboseLogArea textStorage] appendAttributedString:attributedString];
    [verboseLogArea scrollRangeToVisible:NSMakeRange([[verboseLogArea string] length], 0)];
}

// Check hdiutil exit status and act accordingly
- (void)mountAttemptEndedWithStatus:(NSInteger)status{
    [metaSettings setObject:[usersList titleOfSelectedItem] forKey:@"LastUser"];
    [[usersDataStructure objectForKey:[usersList titleOfSelectedItem]]
     setValue:[NSNumber numberWithBool:[checkIntegrity state]] forKey:@"FsckOnMount"];
    [[usersDataStructure objectForKey:[usersList titleOfSelectedItem]]
     setValue:[NSNumber numberWithBool:[verboseMode state]] forKey:@"VerboseMode"];
    [configuration writeToFile:configurationFile atomically:NO];
    
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

// Resize main panel an reposition some elements to fit the verbose log
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

// Remove the following special characters, which cause printf to fail if used in password
// ` " ! % and [backslash]
- (NSString *)sanitizePassword:(NSMutableString *)dirtyPassword{
    NSMutableString *cleanPassword = [NSMutableString stringWithString:dirtyPassword];
    
    [cleanPassword replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:NSLiteralSearch range:NSMakeRange(0, [cleanPassword length])];
    [cleanPassword replaceOccurrencesOfString:@"%" withString:@"%%" options:NSLiteralSearch range:NSMakeRange(0, [cleanPassword length])];
    [cleanPassword replaceOccurrencesOfString:@"!" withString:@"\\!" options:NSLiteralSearch range:NSMakeRange(0, [cleanPassword length])];
    [cleanPassword replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSLiteralSearch range:NSMakeRange(0, [cleanPassword length])];
    [cleanPassword replaceOccurrencesOfString:@"`" withString:@"\\`" options:NSLiteralSearch range:NSMakeRange(0, [cleanPassword length])];
    
    return cleanPassword;
}

@end
