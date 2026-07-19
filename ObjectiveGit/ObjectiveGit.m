//
//  ObjectiveGit.m
//  ObjectiveGitFramework
//
//  Created by Josh Abernathy on 6/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <os/log.h>

#import "git2/common.h"
#import "git2/global.h"

static os_log_t GTLog(void) {
	static os_log_t log;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		log = os_log_create("org.libgit2.objective-git", "init");
	});
	return log;
}

// YES once git_libgit2_init has succeeded; libgit2 calls made while this is NO
// are unsafe.
static BOOL GTLibgit2Initialized = NO;

__attribute__((constructor))
static void GTSetup(void) {
	int initResult = git_libgit2_init();
	if (initResult < 0) {
		os_log_error(GTLog(), "ObjectiveGit failed to initialize libgit2: %d", initResult);
		NSCAssert(NO, @"git_libgit2_init failed: %d", initResult);
		return;
	}

	GTLibgit2Initialized = YES;

	int major = 0, minor = 0, rev = 0;
	git_libgit2_version(&major, &minor, &rev);

	int features = git_libgit2_features();
	os_log_debug(GTLog(), "ObjectiveGit initialized libgit2 %d.%d.%d (threads: %d, https: %d, ssh: %d)",
		major, minor, rev,
		(features & GIT_FEATURE_THREADS) != 0,
		(features & GIT_FEATURE_HTTPS) != 0,
		(features & GIT_FEATURE_SSH) != 0);
}
