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

__attribute__((constructor))
static void GTSetup(void) {
	int initResult = git_libgit2_init();
	if (initResult < 0) {
		NSLog(@"ObjectiveGit failed to initialize libgit2: %d", initResult);
		return;
	}

	int major = 0, minor = 0, rev = 0;
	git_libgit2_version(&major, &minor, &rev);

	int features = git_libgit2_features();
	NSLog(@"ObjectiveGit initialized libgit2 %d.%d.%d (threads: %@, https: %@, ssh: %@)",
		major, minor, rev,
		(features & GIT_FEATURE_THREADS) ? @"yes" : @"no",
		(features & GIT_FEATURE_HTTPS) ? @"yes" : @"no",
		(features & GIT_FEATURE_SSH) ? @"yes" : @"no");
}
