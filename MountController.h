//
//  MountController.h
//  PreLoginMount
//
//  Created by Iliya Lindov on 12/27/13.
//
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface MountController : NSObject{
    IBOutlet NSTextField *statusField;
    IBOutlet NSPopUpButton *usersList;
    IBOutlet NSSecureTextFieldCell *diskUnlockPassword;
}

- (IBAction)mountRequested:(id)sender;

@end