//
//  NSData+Git.m
//

#import "NSData+Git.h"
#import "NSError+Git.h"

#import "git2/errors.h"

#include <string.h>

// Mirrors libgit2's historical `git_buf_is_binary` heuristic (`git_str_is_binary`),
// which was removed from the public API in libgit2 1.x. Reimplemented here with
// direct byte operations so that `-git_isBinary` keeps its previous behavior.
static BOOL GTDataLooksBinary(const void *bytes, NSUInteger length) {
	if (bytes == NULL || length == 0) return NO;

	const unsigned char *scan = bytes;
	const unsigned char *end = scan + length;
	int printable = 0, nonprintable = 0;

	// BOM detection (mirrors `git_str_detect_bom`): a UTF-16 or UTF-32 BOM is
	// treated as binary; a UTF-8 BOM is skipped and does not by itself imply binary.
	if (length >= 2) {
		const unsigned char *b = scan;
		switch (b[0]) {
			case 0x00:
				if (length >= 4 && b[1] == 0x00 && b[2] == 0xFE && b[3] == 0xFF) return YES; // UTF-32 BE
				break;
			case 0xEF:
				if (length >= 3 && b[1] == 0xBB && b[2] == 0xBF) scan += 3; // UTF-8 BOM
				break;
			case 0xFE:
				if (b[1] == 0xFF) return YES; // UTF-16 BE
				break;
			case 0xFF:
				if (b[1] == 0xFE) return YES; // UTF-16 LE / UTF-32 LE
				break;
			default:
				break;
		}
	}

	while (scan < end) {
		unsigned char c = *scan++;

		// Printable characters are those above SPACE (0x1F) excluding DEL,
		// and including BS, ESC and FF.
		if ((c > 0x1F && c != 127) || c == '\b' || c == '\033' || c == '\014') {
			printable++;
		} else if (c == '\0') {
			return YES;
		} else if (!(c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r')) {
			nonprintable++;
		}
	}

	return (printable >> 7) < nonprintable;
}

// Libgit2-owned output buffers carry their allocation size in `reserved`.
// Buffers created by `-git_buf` (and legacy constant buffers) leave it at zero
// to identify a borrowed pointer that must not be passed to git_buf_dispose().
static void GTConsumeBuffer(git_buf *buffer) {
	if (buffer->reserved > 0) {
		git_buf_dispose(buffer);
	}

	*buffer = (git_buf)GIT_BUF_INIT;
}

@implementation NSData (Git)

+ (NSData *)git_dataWithOid:(git_oid *)oid {
    return [NSData dataWithBytes:oid length:sizeof(git_oid)];
}

- (BOOL)git_getOid:(git_oid *)oid error:(NSError **)error {
    if ([self length] != sizeof(git_oid)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:GTGitErrorDomain 
                                         code:GIT_ERROR_INVALID
                                     userInfo:
                      [NSDictionary dictionaryWithObject:@"can't extract oid from data of incorrect length" 
                                                  forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }
    
    [self getBytes:oid length:sizeof(git_oid)];
    return YES;
}

+ (instancetype)git_dataWithBuffer:(git_buf *)buffer {
	NSCParameterAssert(buffer != NULL);

	if (buffer->ptr == NULL || buffer->size == 0) {
		GTConsumeBuffer(buffer);
		return [self data];
	}

	// Copy before consuming the buffer so this works for both libgit2-owned
	// output and the borrowed view returned by -git_buf.
	NSData *data = [self dataWithBytes:buffer->ptr length:buffer->size];
	GTConsumeBuffer(buffer);

	return data;
}

- (git_buf)git_buf {
	// A non-owning, read-only view over the receiver's bytes. The middle
	// `reserved` field of `git_buf` (libgit2 1.x) is left zeroed.
	git_buf buffer = GIT_BUF_INIT;
	buffer.ptr = (char *)self.bytes;
	buffer.size = self.length;
	return buffer;
}

- (BOOL)git_containsNUL {
	// Empty NSData may report NULL bytes, which memchr must never receive.
	const void *bytes = self.bytes;
	if (bytes == NULL || self.length == 0) return NO;
	return memchr(bytes, '\0', self.length) != NULL;
}

- (BOOL)git_isBinary {
	return GTDataLooksBinary(self.bytes, self.length);
}

@end
