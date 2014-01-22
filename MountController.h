/*
 
 PreLoginMount - mount disk images, sparse images and sparse bundles before user logon.
 Copyright (C) 2014  Iliya Lindov
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 
*/

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
    IBOutlet NSProgressIndicator *spinner;
    IBOutlet NSButton *checkIntegrity;
    IBOutlet NSButton *verboseMode;
    IBOutlet NSButton *mountButton;
    IBOutlet NSButton *closeAndContinueButton;
    IBOutlet NSButton *clearVerboseLogArea;
    IBOutlet NSTextView *verboseLogArea;
}

- (IBAction)attemptToMountWithPassword:(id)sender;
- (IBAction)showVerboseLog:(id)sender;
- (IBAction)clearVerboseLog:(id)sender;
- (IBAction)closeApplication:(id)sender;

@end
