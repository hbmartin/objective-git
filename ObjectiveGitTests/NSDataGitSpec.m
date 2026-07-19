//
//  NSDataGitSpec.m
//  ObjectiveGitFramework
//
//  Created by Justin Spahr-Summers on 2014-06-27.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

@import ObjectiveGit;
@import Nimble;
@import Quick;

#import "QuickSpec+GTFixtures.h"

QuickSpecBegin(NSDataGit)

const void *testData = "hello world";
const size_t testDataSize = strlen(testData) + 1;

describe(@"+git_dataWithBuffer:", ^{
	__block git_buf buffer;

	beforeEach(^{
		buffer = (git_buf)GIT_BUF_INIT_CONST(NULL, 0);
		expect(@(git_buf_set(&buffer, testData, testDataSize))).to(equal(@(GIT_OK)));

		expect([NSValue valueWithPointer:buffer.ptr]).notTo(equal([NSValue valueWithPointer:NULL]));
		expect([NSValue valueWithPointer:buffer.ptr]).notTo(equal([NSValue valueWithPointer:testData]));
		expect(@(buffer.size)).to(equal(@(testDataSize)));
		expect(@(buffer.asize)).to(beGreaterThanOrEqualTo(@(testDataSize)));
	});

	afterEach(^{
		git_buf_free(&buffer);
	});

	it(@"should create matching NSData", ^{
		NSData *data = [NSData git_dataWithBuffer:&buffer];
		expect(data).notTo(beNil());

		expect(@(data.length)).to(equal(@(testDataSize)));
		expect(@(memcmp(data.bytes, testData, testDataSize))).to(equal(@0));
	});

	it(@"should invalidate the buffer", ^{
		[NSData git_dataWithBuffer:&buffer];

		expect(@(buffer.size)).to(equal(@0));
		expect(@(buffer.asize)).to(equal(@0));
		expect([NSValue valueWithPointer:buffer.ptr]).to(equal([NSValue valueWithPointer:NULL]));
	});

	it(@"should preserve an empty buffer", ^{
		git_buf_free(&buffer);
		buffer = (git_buf)GIT_BUF_INIT_CONST(NULL, 0);

		NSData *data = [NSData git_dataWithBuffer:&buffer];

		expect(data).notTo(beNil());
		expect(@(data.length)).to(equal(@0));
		expect(@(buffer.size)).to(equal(@0));
		expect([NSValue valueWithPointer:buffer.ptr]).to(equal([NSValue valueWithPointer:NULL]));
	});
});

describe(@"git_buf", ^{
	__block NSData *data;

	beforeEach(^{
		data = [NSData dataWithBytes:testData length:testDataSize];
		expect(data).notTo(beNil());
	});

	it(@"should return a constant buffer of the data's bytes", ^{
		git_buf buffer = data.git_buf;
		expect([NSValue valueWithPointer:buffer.ptr]).to(equal([NSValue valueWithPointer:data.bytes]));
		expect(@(buffer.size)).to(equal(@(data.length)));
		expect(@(buffer.asize)).to(equal(@0));
	});
});

describe(@"data classification", ^{
	it(@"should detect embedded NUL bytes", ^{
		const unsigned char bytes[] = { 'g', 'i', 't', 0, 'x' };
		NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];

		expect(@(data.git_containsNUL)).to(beTruthy());
		expect(@(data.git_isBinary)).to(beTruthy());
	});

	it(@"should keep ordinary UTF-8 text classified as text", ^{
		NSData *data = [@"GitX Snow Leopard" dataUsingEncoding:NSUTF8StringEncoding];

		expect(@(data.git_containsNUL)).to(beFalsy());
		expect(@(data.git_isBinary)).to(beFalsy());
	});
});

afterEach(^{
	[self tearDown];
});

QuickSpecEnd
