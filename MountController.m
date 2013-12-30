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
    NSLog(@"Maleleiii - %@\n", [diskUnlockPassword objectValue]);
    NSLog(@"Selected - %@", [usersList titleOfSelectedItem]);
    [statusField setObjectValue:@"Attempting to mount..."];
    [self attemptToMount:_diskFilePath withPassword:[diskUnlockPassword objectValue]];
}

- (BOOL)attemptToMount:(NSString *)diskFilePath
          withPassword:(NSString *)password {
    NSLog(@"Path: '%@'; Password: '%@'\n", diskFilePath, password);
    
    return NO;
}

@end
