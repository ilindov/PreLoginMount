//
//  MountController.m
//  PreLoginMount
//
//  Created by Iliya Lindov on 12/27/13.
//
//

#import "MountController.h"

@implementation MountController

NSString *_diskFilePath = @"/Users/ilia/Desktop/test.sparsebundle";

- (void) awakeFromNib{
    [statusField setObjectValue:@"Initialized..."];
    [usersList removeAllItems];
    [usersList addItemWithTitle:@"Iliya Lindov"];
    [usersList addItemWithTitle:@"Petya Lindova"];
}

- (IBAction)mountRequested:(id)sender{
    [statusField setObjectValue:@"Attempting to mount..."];
    BOOL result = [self attemptToMount:_diskFilePath withPassword:[diskUnlockPassword objectValue]];
    if (result){
        [NSApp terminate:self];
    }
}

- (BOOL)attemptToMount:(NSString *)diskFilePath
          withPassword:(NSString *)password {
    NSLog(@"Path: '%@'; Password: '%@'\n", diskFilePath, password);
    @try {
        NSTask *execution = [[NSTask alloc] init];
        [execution setLaunchPath:@"/bin/echo"];
        [execution setArguments:[[NSArray alloc] initWithObjects:@"'123' >/tmp/777.txt", nil]];
        [execution launch];
        [execution waitUntilExit];
    }
    @catch (NSException *exception) {
        NSLog(@"Exception - %@", [exception reason]);
    }

    return NO;
}

@end
