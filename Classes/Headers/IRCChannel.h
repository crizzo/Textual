// Created by Satoshi Nakagawa <psychs AT limechat DOT net> <http://github.com/psychs/limechat>
// Modifications by Codeux Software <support AT codeux DOT com> <https://github.com/codeux/Textual>
// You can redistribute it and/or modify it under the new BSD license.

@class IRCClient;

@interface MemberGroup : NSObject {
    char mark;
    NSMutableArray *users;
}
@property (nonatomic, readonly) char mark;
@property (nonatomic, readonly) NSMutableArray *users;
- (NSString *)name;
- (id)initWithMark:(char)m;
@end


@interface IRCChannel : IRCTreeItem
{
	IRCClient *client;
	IRCChannelMode *mode;
	IRCChannelConfig *config;
	
	NSMutableArray *members;
    NSMutableArray *groups;
	NSString *topic;
	NSString *storedTopic;
	
	NSString *logDate;
	
	BOOL isActive;
	BOOL isOp;
	BOOL isHalfOp;
	BOOL isModeInit;
	BOOL isNamesInit;
	BOOL isWhoInit;
	
	BOOL forceOutput;
	BOOL errLastJoin;
	
	FileLogger *logFile;
}

@property (nonatomic, assign) IRCClient *client;
@property (nonatomic, readonly) IRCChannelMode *mode;
@property (nonatomic, readonly) IRCChannelConfig *config;
@property (nonatomic, readonly) NSMutableArray *members;
@property (nonatomic, readonly) NSString *channelTypeString;
@property (nonatomic, retain) NSString *topic;
@property (nonatomic, retain) NSString *storedTopic;
@property (nonatomic, retain) NSString *logDate;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) BOOL isOp;
@property (nonatomic, assign) BOOL isHalfOp;
@property (nonatomic, assign) BOOL isModeInit;
@property (nonatomic, assign) BOOL isNamesInit;
@property (nonatomic, assign) BOOL isWhoInit;
@property (nonatomic, assign) BOOL forceOutput;
@property (nonatomic, assign) BOOL errLastJoin;
@property (nonatomic, readonly) BOOL isChannel;
@property (nonatomic, readonly) BOOL isTalk;
@property (nonatomic, retain) FileLogger *logFile;
@property (nonatomic, assign) NSString *name;
@property (nonatomic, readonly) NSString *password;

- (void)setup:(IRCChannelConfig *)seed;
- (void)updateConfig:(IRCChannelConfig *)seed;
- (NSMutableDictionary *)dictionaryValue;

- (void)terminate;
- (void)closeDialogs;
- (void)preferencesChanged;

- (void)activate;
- (void)deactivate;
- (void)detectOutgoingConversation:(NSString *)text;

- (BOOL)print:(LogLine *)line;
- (BOOL)print:(LogLine *)line withHTML:(BOOL)rawHTML;

- (void)addMember:(IRCUser *)user;
- (void)addMember:(IRCUser *)user reload:(BOOL)reload;

- (void)removeMember:(NSString *)nick;
- (void)removeMember:(NSString *)nick reload:(BOOL)reload;

- (void)renameMember:(NSString *)fromNick to:(NSString *)toNick;

- (void)updateOrAddMember:(IRCUser *)user;
- (void)changeMember:(NSString *)nick mode:(char)mode value:(BOOL)value;

- (void)clearMembers;

- (IRCUser *)memberAtIndex:(NSInteger)index;
- (IRCUser *)memberAtRow:(NSInteger)index;
- (IRCUser *)findMember:(NSString *)nick;
- (IRCUser *)findMember:(NSString *)nick options:(NSStringCompareOptions)mask;
- (NSInteger)indexOfMember:(NSString *)nick;
- (NSInteger)indexOfMember:(NSString *)nick options:(NSStringCompareOptions)mask;

- (NSInteger)numberOfMembers;

- (void)reloadMemberList;
@end
