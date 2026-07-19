//
//  ObjectiveGit.m
//  ObjectiveGitFramework
//
//  Created by Josh Abernathy on 6/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "git2/common.h"
#import "git2/global.h"

// YES once git_libgit2_init has succeeded; libgit2 calls made while this is NO
// are unsafe.
static BOOL GTLibgit2Initialized = NO;

__attribute__((constructor))
static void GTSetup(void) {
	int initResult = git_libgit2_init();
	if (initResult < 0) {
		NSLog(@"ObjectiveGit failed to initialize libgit2: %d", initResult);
		NSCAssert(NO, @"git_libgit2_init failed: %d", initResult);
		return;
	}

	GTLibgit2Initialized = YES;

	int major = 0, minor = 0, rev = 0;
	git_libgit2_version(&major, &minor, &rev);

	int features = git_libgit2_features();
	NSLog(@"ObjectiveGit initialized libgit2 %d.%d.%d (threads: %@, https: %@, ssh: %@)",
		major, minor, rev,
		(features & GIT_FEATURE_THREADS) ? @"yes" : @"no",
		(features & GIT_FEATURE_HTTPS) ? @"yes" : @"no",
		(features & GIT_FEATURE_SSH) ? @"yes" : @"no");
}
