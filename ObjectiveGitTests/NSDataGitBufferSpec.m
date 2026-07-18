//
//  NSDataGitBufferSpec.m
//  ObjectiveGitFramework
//
//  Characterizes NSData's NUL / binary detection helpers, which are backed by
//  the libgit2 `git_buf_is_binary` heuristic before the upgrade and by an
//  equivalent direct-byte reimplementation afterwards.
//

@import ObjectiveGit;
@import Nimble;
@import Quick;

#import "QuickSpec+GTFixtures.h"

QuickSpecBegin(NSDataGitBufferSpec)

describe(@"-git_containsNUL", ^{
	it(@"is NO for empty data", ^{
		expect(@([[NSData data] git_containsNUL])).to(beFalsy());
	});

	it(@"is NO for plain text", ^{
		NSData *data = [@"hello world" dataUsingEncoding:NSUTF8StringEncoding];
		expect(@([data git_containsNUL])).to(beFalsy());
	});

	it(@"is YES when a NUL byte is present", ^{
		const char bytes[] = { 'a', 'b', 0x00, 'c' };
		NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
		expect(@([data git_containsNUL])).to(beTruthy());
	});
});

describe(@"-git_isBinary", ^{
	it(@"is NO for empty data", ^{
		expect(@([[NSData data] git_isBinary])).to(beFalsy());
	});

	it(@"is NO for plain text with a trailing newline", ^{
		NSData *data = [@"the quick brown fox\n" dataUsingEncoding:NSUTF8StringEncoding];
		expect(@([data git_isBinary])).to(beFalsy());
	});

	it(@"is YES for data containing a NUL byte", ^{
		const char bytes[] = { 'a', 0x00, 'b' };
		NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
		expect(@([data git_isBinary])).to(beTruthy());
	});

	it(@"is YES for mostly non-printable data", ^{
		unsigned char bytes[64];
		for (NSUInteger i = 0; i < sizeof(bytes); i++) {
			bytes[i] = (unsigned char)(i % 7 + 1); // control bytes 0x01..0x07 (no NUL, no whitespace)
		}
		NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
		expect(@([data git_isBinary])).to(beTruthy());
	});
});

QuickSpecEnd
