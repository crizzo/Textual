// Created by Satoshi Nakagawa <psychs AT limechat DOT net> <http://github.com/psychs/limechat>
// Modifications by Codeux Software <support AT codeux DOT com> <https://github.com/codeux/Textual>
// You can redistribute it and/or modify it under the new BSD license.

@interface IRCChannel (Private)
- (void)closeLogFile;
@end

@implementation IRCChannel

@synthesize client;
@synthesize config;
@synthesize errLastJoin;
@synthesize forceOutput;
@synthesize isActive;
@synthesize isHalfOp;
@synthesize isModeInit;
@synthesize isNamesInit;
@synthesize isOp;
@synthesize isWhoInit;
@synthesize logDate;
@synthesize logFile;
@synthesize members;
@synthesize mode;
@synthesize storedTopic;
@synthesize topic;

- (id)init
{
	if ((self = [super init])) {
		mode = [IRCChannelMode new];
		members = [NSMutableArray new];
        groups = [NSMutableArray new];
        [groups addObject:[[MemberGroup alloc] initWithMark:'~']];
        [groups addObject:[[MemberGroup alloc] initWithMark:'&']];
        [groups addObject:[[MemberGroup alloc] initWithMark:'@']];
        [groups addObject:[[MemberGroup alloc] initWithMark:'%']];
        [groups addObject:[[MemberGroup alloc] initWithMark:'+']];
        [groups addObject:[[MemberGroup alloc] initWithMark:' ']];
	}
	
	return self;
}

- (void)dealloc
{
	[mode drain];
	[topic drain];	
	[config drain];
	[logDate drain];
	[logFile drain];
	[members drain];
	[storedTopic drain];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Init

- (void)setup:(IRCChannelConfig *)seed
{
	[config autodrain];
	config = [seed mutableCopy];
}

- (void)updateConfig:(IRCChannelConfig *)seed
{
	[config autodrain];
	config = [seed mutableCopy];
}

- (NSMutableDictionary *)dictionaryValue
{
	return [config dictionaryValue];
}

#pragma mark -
#pragma mark Properties

- (NSString *)name
{
	return config.name;
}

- (void)setName:(NSString *)value
{
	config.name = value;
}

- (NSString *)password
{
	return ((config.password) ?: @"");
}

- (BOOL)isChannel
{
	return (config.type == CHANNEL_TYPE_CHANNEL);
}

- (BOOL)isTalk
{
	return (config.type == CHANNEL_TYPE_TALK);
}

- (NSString *)channelTypeString
{
	switch (config.type) {
		case CHANNEL_TYPE_CHANNEL: return @"channel";
		case CHANNEL_TYPE_TALK: return @"talk";
	}
	
	return nil;
}

#pragma mark -
#pragma mark Utilities

- (void)terminate
{
	[self closeDialogs];
	[self closeLogFile];
}

- (void)closeDialogs
{
	return;
}

- (void)preferencesChanged
{
	log.maxLines = [Preferences maxLogLines];
	
	if (logFile) {
		if ([Preferences logTranscript]) {
			[logFile reopenIfNeeded];
		} else {
			[self closeLogFile];
		}
	}
}

- (void)activate
{
	isActive = YES;
	
	[members removeAllObjects];
    for (id g in groups) [[g users] removeAllObjects];
	[mode clear];
	[members removeAllObjects];
	
	isOp = NO;
	isHalfOp = NO;
	
	self.topic = nil;
	
	isWhoInit = NO;
	isModeInit = NO;
	isNamesInit = NO;
	forceOutput = NO;
	errLastJoin = NO;
	
	[self reloadMemberList];
    [client.world.memberList expandItem:nil expandChildren:YES];
}

- (void)deactivate
{
	isActive = NO;
	
	[members removeAllObjects];
	
    for (id g in groups) [[g users] removeAllObjects];
	isOp = NO;
	isHalfOp = NO;
	
	forceOutput = NO;
	errLastJoin = NO;
	
	[self reloadMemberList];
}

- (void)detectOutgoingConversation:(NSString *)text
{
	if (NSObjectIsNotEmpty([Preferences completionSuffix])) {
		NSArray *pieces = [text split:[Preferences completionSuffix]];
		
		if ([pieces count] > 1) {
			IRCUser *talker = [self findMember:[pieces safeObjectAtIndex:0]];
			
			if (talker) {
				[talker incomingConversation];
			}
		}
	}
}

- (BOOL)print:(LogLine *)line
{
	return [self print:line withHTML:NO];
}

- (BOOL)print:(LogLine *)line withHTML:(BOOL)rawHTML
{
	BOOL result = [log print:line withHTML:rawHTML];
	
	if ([Preferences logTranscript]) {
		if (PointerIsEmpty(logFile)) {
			logFile = [FileLogger new];
			logFile.client = client;
			logFile.channel = self;
		}
		
		NSString *comp = [NSString stringWithFormat:@"%@", [[NSDate date] dateWithCalendarFormat:@"%Y%m%d%H%M%S" timeZone:nil]];
		
		if (logDate) {
			if ([logDate isEqualToString:comp] == NO) {
				[logDate drain];
				
				logDate = [comp retain];
				[logFile reopenIfNeeded];
			}
		} else {
			logDate = [comp retain];
		}
		
		NSString *nickStr = @"";
		
		if (line.nick) {
			nickStr = [NSString stringWithFormat:@"%@: ", line.nickInfo];
		}
		
		NSString *s = [NSString stringWithFormat:@"%@%@%@", line.time, nickStr, line.body];
		
		[logFile writeLine:s];
	}
	
	return result;
}

#pragma mark -
#pragma mark Member List

- (void)sortedInsert:(IRCUser *)item
{
	const NSInteger LINEAR_SEARCH_THRESHOLD = 5;
	
	NSInteger left = 0;
	NSInteger right = members.count;
	
	while (right - left > LINEAR_SEARCH_THRESHOLD) {
		NSInteger i = ((left + right) / 2);
		
		IRCUser *t = [members safeObjectAtIndex:i];
		
		if ([t compare:item] == NSOrderedAscending) {
			left = (i + 1);
		} else {
			right = (i + 1);
		}
	}
	
	for (NSInteger i = left; i < right; ++i) {
		IRCUser *t = [members safeObjectAtIndex:i];
		
		if ([t compare:item] == NSOrderedDescending) {
			[members safeInsertObject:item atIndex:i];
			
			return;
		}
	}
	
	[members safeAddObject:item];
}

- (void)addMember:(IRCUser *)user
{
	[self addMember:user reload:YES];
}

- (void)addMember:(IRCUser *)user reload:(BOOL)reload
{
	NSInteger n = [self indexOfMember:user.nick];
	
	if (n >= 0) {
		[[[members safeObjectAtIndex:n] retain] autodrain];
		
		[members safeRemoveObjectAtIndex:n];
	}
	
	[self sortedInsert:user];
	
	if (reload) {
		[self reloadMemberList];
	}
}

- (void)removeMember:(NSString *)nick
{
	[self removeMember:nick reload:YES];
}

- (void)removeMember:(NSString *)nick reload:(BOOL)reload
{
	NSInteger n = [self indexOfMember:nick];
	
	if (n >= 0) {
		[[[members safeObjectAtIndex:n] retain] autodrain];
		
		[members safeRemoveObjectAtIndex:n];
	}
	
	if (reload) [self reloadMemberList];
}

- (void)renameMember:(NSString *)fromNick to:(NSString *)toNick
{
	NSInteger n = [self indexOfMember:fromNick];
	
	if (n >= 0) {
		IRCUser *m = [members safeObjectAtIndex:n];
		
		[[m retain] autodrain];
		
		[self removeMember:toNick reload:NO];
		
		m.nick = toNick;
		
		[[[members safeObjectAtIndex:n] retain] autodrain];
		
		[members safeRemoveObjectAtIndex:n];
		
		[self sortedInsert:m];
		[self reloadMemberList];
	}
}

- (void)updateOrAddMember:(IRCUser *)user
{
	NSInteger n = [self indexOfMember:user.nick];
	
	if (n >= 0) {
		[[[members safeObjectAtIndex:n] retain] autodrain];
		
		[members safeRemoveObjectAtIndex:n];
	}
	
	[self sortedInsert:user];
}

- (void)changeMember:(NSString *)nick mode:(char)modeChar value:(BOOL)value
{
	NSInteger n = [self indexOfMember:nick];
	
	if (n >= 0) {
		IRCUser *m = [members safeObjectAtIndex:n];
		
		switch (modeChar) {
			case 'q': m.q = value; break;
			case 'a': m.a = value; break;
			case 'o': m.o = value; break;
			case 'h': m.h = value; break;
			case 'v': m.v = value; break;
		}
		
		if ([Preferences useStrictModeMatching] && client.isupport.supportsExtraModes == NO) {
			m.q = NO;
			m.a = NO;
			m.o = YES;
		}
		
		[[[members safeObjectAtIndex:n] retain] autodrain];
		
		[members safeRemoveObjectAtIndex:n];
		
		[self sortedInsert:m];
		[self reloadMemberList];
	}
}

- (void)clearMembers
{
	[members removeAllObjects];
	
    for (id g in groups) [[g users] removeAllObjects];
	[self reloadMemberList];
}

- (NSInteger)indexOfMember:(NSString *)nick
{
	return [self indexOfMember:nick options:0];
}

- (NSInteger)indexOfMember:(NSString *)nick options:(NSStringCompareOptions)mask
{
	NSInteger i = -1;
	
	for (IRCUser *m in members) {
		i++;
		
		if (mask & NSCaseInsensitiveSearch) {
			if ([nick isEqualNoCase:m.nick]) {
				return i;
			}
		} else {
			if ([m.nick isEqualToString:nick]) {
				return i;
			}
		}
	}
	
	return -1;
}

- (IRCUser *)memberAtIndex:(NSInteger)index
{
    return [members safeObjectAtIndex:index];
}

- (IRCUser *)memberAtRow:(NSInteger)index
{
	int r = index;
    int x = 0;
    int go = 0;
    for (MemberGroup *g in groups) {
        if ([[g users] count] > 0) {
            go += 1;
            x += [[g users] count] + 1;
            if (x >= r) break;
        }
    }
    return [self memberAtIndex:r - go];
}

- (IRCUser *)findMember:(NSString *)nick
{
	return [self findMember:nick options:0];
}

- (IRCUser *)findMember:(NSString *)nick options:(NSStringCompareOptions)mask
{
	NSInteger n = [self indexOfMember:nick options:mask];
	
	if (n >= 0) {
		return [members safeObjectAtIndex:n];
	}
	
	return nil;
}

- (NSInteger)numberOfMembers
{
	return members.count;
}

- (NSArray *)types {
    NSMutableArray *a = [NSMutableArray new];
    for (MemberGroup *g in groups)
        [a addObject:[NSString stringWithChar:[g mark]]];
    return a;
}

- (void)reloadMemberList
{
	if (client.world.selected == self) {
        for (id g in groups) [[g users] removeAllObjects];
        
        NSMutableDictionary *d = [NSMutableDictionary new];
        for (MemberGroup *m in groups) {
            NSString *s = [NSString stringWithChar:[m mark]];
            [d setObject:m forKey:s];
        }

        for (int i = 0; i < [members count]; i++) {
            IRCUser *u = [members objectAtIndex:i];
            NSString *g = [NSString stringWithChar:[u mark]];
            MemberGroup *m = [d objectForKey:g];
            
            [[m users] addObject:u];
        }
            
		[client.world.memberList reloadData];
	}
}

- (void)closeLogFile
{
	if (logFile) {
		[logFile close];
	}
}

#pragma mark -
#pragma mark IRCTreeItem

- (BOOL)isClient
{
	return NO;
}

- (NSInteger)numberOfChildren
{
	return 0;
}

- (id)childAtIndex:(NSInteger)index
{
	return nil;
}

- (NSString *)label
{
	return config.name;
}

#pragma mark -
#pragma mark NSOutlineView Delegate

- (id)notemptygroups {
    NSMutableArray *a = [NSMutableArray new];
    for (MemberGroup *g in groups) if ([[g users] count]) [a addObject:g];
    return a;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(MemberGroup *)item
{
    if (item != nil) return [[item users] count];
    else return [[self notemptygroups] count];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    id ret = nil;
	if ([item isKindOfClass:[MemberGroup class]]) {
        ret = [(MemberGroup *) item name];
        if ([[item users] count] == 0) ret = nil;
    } else {
        int i = [item intValue];
        MemberGroup *g = [groups objectAtIndex:i >> 24];
        int x = i & 0x00FFFFFF;
        IRCUser *u = [[g users] objectAtIndex:x];
        ret = [u nick];
    }
    return ret;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(MemberGroup *)item
{
    id ret = nil;
    if (item != nil) ret = [[NSNumber numberWithInt:index | ([groups indexOfObject:item] << 24)] retain];
    else ret = [[self notemptygroups] objectAtIndex:index];
    return ret;
}

- (BOOL)outlineView:(NSOutlineView *)sender isGroupItem:(id)item {
    return [item isKindOfClass:[MemberGroup class]];
}

/*- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	return ([client.world.viewTheme.other.memberListFont pointSize] + 3.0); // Long callback
}*/

- (id)tableView:(NSTableView *)sender objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	IRCUser *user = [members safeObjectAtIndex:row];
	
	return TXTFLS(@"ACCESSIBILITY_MEMBER_LIST_DESCRIPTION", [user nick], [config.name safeSubstringFromIndex:1]);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [item isKindOfClass:[MemberGroup class]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return ![item isKindOfClass:[MemberGroup class]];
}

@end


@implementation MemberGroup
@synthesize mark;
@synthesize users;
- (id)initWithMark:(char)m 
{
    self = [super init];
    mark = m;
    users = [[NSMutableArray new] retain];
    return self;
}
- (NSString *)name {
    switch(mark) {
        case '~': return @"OWNER";
        case '&': return @"PROTECTED";
        case '@': return @"OPERATOR";
        case '%': return @"HALFOP";
        case '+': return @"VOICE";
        case ' ': return @"NORMAL";
    }
    return nil;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<MemberGroup mark=%c count=%d>", mark, [users count]];
}
@end



