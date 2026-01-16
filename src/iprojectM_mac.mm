// main drawing and interface code for Mac OS iTunes
// Mischa Spiegelmock, 2012

// based on the iTunes SDK example code

// https://www.fenestrated.net/mirrors/Apple%20Technotes%20(As%20of%202002)/tn/tn2016.html

#import "iprojectM.hpp"
#import "projectM-4/playlist.h"

#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <OpenGL/gl3.h>
#import <QuartzCore/CABase.h>
#import <string.h>

#define kTVisualPluginName CFSTR("projectM")

// NSUserDefaults keys for settings persistence
static NSString * const kProjectMVSyncEnabled = @"projectM.vsyncEnabled";
static NSString * const kProjectMMeshQuality = @"projectM.meshQuality";  // 0=auto, 1=high, 2=medium, 3=low
static NSString * const kProjectMPresetDuration = @"projectM.presetDuration";
static NSString * const kProjectMBeatSensitivity = @"projectM.beatSensitivity";

extern "C" OSStatus iTunesPluginMainMachO( OSType inMessage, PluginMessageInfo *inMessageInfoPtr, void *refCon ) __attribute__((visibility("default")));

#if USE_SUBVIEW
@interface VisualView : NSOpenGLView
{
	VisualPluginData *	_visualPluginData;
	NSTextField *		_fpsLabel;
}

@property (nonatomic, assign) VisualPluginData * visualPluginData;

- (void)drawRect:(NSRect)dirtyRect;
- (BOOL)acceptsFirstResponder;
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
- (void)keyDown:(NSEvent *)theEvent;
- (void)keyUp:(NSEvent *)theEvent;
- (void)updateFPSDisplay;

@end

#endif	// USE_SUBVIEW

#pragma mark - Settings Panel

@interface ProjectMSettingsPanel : NSObject <NSWindowDelegate>
{
	NSWindow *_window;
	VisualPluginData *_visualPluginData;
	NSButton *_vsyncCheckbox;
	NSPopUpButton *_meshQualityPopup;
	NSSlider *_presetDurationSlider;
	NSSlider *_beatSensitivitySlider;
	NSTextField *_presetDurationLabel;
	NSTextField *_beatSensitivityLabel;
}

+ (instancetype)sharedPanel;
- (void)showWithPluginData:(VisualPluginData *)pluginData;

@end

@implementation ProjectMSettingsPanel

+ (instancetype)sharedPanel {
	static ProjectMSettingsPanel *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[ProjectMSettingsPanel alloc] init];
	});
	return sharedInstance;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		[self createWindow];
	}
	return self;
}

- (void)createWindow {
	NSRect frame = NSMakeRect(0, 0, 340, 260);
	_window = [[NSWindow alloc] initWithContentRect:frame
										  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
											backing:NSBackingStoreBuffered
											  defer:NO];
	_window.title = @"projectM Settings";
	_window.delegate = self;
	[_window center];

	NSView *contentView = _window.contentView;
	CGFloat y = frame.size.height - 40;
	CGFloat labelWidth = 120;
	CGFloat controlX = 130;

	// VSync checkbox
	_vsyncCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, y, 300, 20)];
	_vsyncCheckbox.buttonType = NSButtonTypeSwitch;
	_vsyncCheckbox.title = @"Enable VSync (smoother, caps FPS)";
	_vsyncCheckbox.target = self;
	_vsyncCheckbox.action = @selector(vsyncChanged:);
	[contentView addSubview:_vsyncCheckbox];
	y -= 35;

	// Mesh Quality
	NSTextField *meshLabel = [NSTextField labelWithString:@"Mesh Quality:"];
	meshLabel.frame = NSMakeRect(20, y, labelWidth, 20);
	[contentView addSubview:meshLabel];

	_meshQualityPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(controlX, y - 2, 180, 26) pullsDown:NO];
	[_meshQualityPopup addItemsWithTitles:@[@"Auto (Adaptive)", @"High (140×110)", @"Medium (96×72)", @"Low (64×48)"]];
	_meshQualityPopup.target = self;
	_meshQualityPopup.action = @selector(meshQualityChanged:);
	[contentView addSubview:_meshQualityPopup];
	y -= 40;

	// Preset Duration
	NSTextField *durationLabel = [NSTextField labelWithString:@"Preset Duration:"];
	durationLabel.frame = NSMakeRect(20, y, labelWidth, 20);
	[contentView addSubview:durationLabel];

	_presetDurationSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(controlX, y, 140, 20)];
	_presetDurationSlider.minValue = 5;
	_presetDurationSlider.maxValue = 120;
	_presetDurationSlider.target = self;
	_presetDurationSlider.action = @selector(presetDurationChanged:);
	[contentView addSubview:_presetDurationSlider];

	_presetDurationLabel = [NSTextField labelWithString:@"30s"];
	_presetDurationLabel.frame = NSMakeRect(280, y, 40, 20);
	[contentView addSubview:_presetDurationLabel];
	y -= 40;

	// Beat Sensitivity
	NSTextField *beatLabel = [NSTextField labelWithString:@"Beat Sensitivity:"];
	beatLabel.frame = NSMakeRect(20, y, labelWidth, 20);
	[contentView addSubview:beatLabel];

	_beatSensitivitySlider = [[NSSlider alloc] initWithFrame:NSMakeRect(controlX, y, 140, 20)];
	_beatSensitivitySlider.minValue = 0.5;
	_beatSensitivitySlider.maxValue = 5.0;
	_beatSensitivitySlider.target = self;
	_beatSensitivitySlider.action = @selector(beatSensitivityChanged:);
	[contentView addSubview:_beatSensitivitySlider];

	_beatSensitivityLabel = [NSTextField labelWithString:@"3.0"];
	_beatSensitivityLabel.frame = NSMakeRect(280, y, 40, 20);
	[contentView addSubview:_beatSensitivityLabel];
	y -= 50;

	// Keyboard shortcuts info
	NSTextField *shortcutsTitle = [NSTextField labelWithString:@"Keyboard Shortcuts:"];
	shortcutsTitle.font = [NSFont boldSystemFontOfSize:11];
	shortcutsTitle.frame = NSMakeRect(20, y, 300, 16);
	[contentView addSubview:shortcutsTitle];
	y -= 18;

	NSTextField *shortcutsText = [NSTextField labelWithString:@"n/p: Next/Prev preset  r: Random  l: Lock\nf: Toggle FPS  0: Auto mesh  1/2/3: Force quality"];
	shortcutsText.font = [NSFont systemFontOfSize:10];
	shortcutsText.frame = NSMakeRect(20, y - 16, 300, 32);
	[contentView addSubview:shortcutsText];
}

- (void)showWithPluginData:(VisualPluginData *)pluginData {
	_visualPluginData = pluginData;
	[self loadSettings];
	[_window makeKeyAndOrderFront:nil];
	[NSApp activateIgnoringOtherApps:YES];
}

- (void)loadSettings {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	// VSync - default to NO (disabled for performance measurement)
	BOOL vsync = [defaults objectForKey:kProjectMVSyncEnabled] ? [defaults boolForKey:kProjectMVSyncEnabled] : NO;
	_vsyncCheckbox.state = vsync ? NSControlStateValueOn : NSControlStateValueOff;

	// Mesh quality - 0=auto, 1=high, 2=medium, 3=low
	NSInteger meshQuality = [defaults objectForKey:kProjectMMeshQuality] ? [defaults integerForKey:kProjectMMeshQuality] : 0;
	[_meshQualityPopup selectItemAtIndex:meshQuality];

	// Preset duration - default 30s
	double duration = [defaults objectForKey:kProjectMPresetDuration] ? [defaults doubleForKey:kProjectMPresetDuration] : 30.0;
	_presetDurationSlider.doubleValue = duration;
	_presetDurationLabel.stringValue = [NSString stringWithFormat:@"%.0fs", duration];

	// Beat sensitivity - default 3.0
	double sensitivity = [defaults objectForKey:kProjectMBeatSensitivity] ? [defaults doubleForKey:kProjectMBeatSensitivity] : 3.0;
	_beatSensitivitySlider.doubleValue = sensitivity;
	_beatSensitivityLabel.stringValue = [NSString stringWithFormat:@"%.1f", sensitivity];
}

- (void)vsyncChanged:(NSButton *)sender {
	BOOL enabled = (sender.state == NSControlStateValueOn);
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kProjectMVSyncEnabled];

	// Apply immediately if we have an OpenGL context
	if (_visualPluginData && _visualPluginData->subview) {
		GLint swapInterval = enabled ? 1 : 0;
		[[_visualPluginData->subview openGLContext] setValues:&swapInterval forParameter:NSOpenGLCPSwapInterval];
	}
}

- (void)meshQualityChanged:(NSPopUpButton *)sender {
	NSInteger selection = sender.indexOfSelectedItem;
	[[NSUserDefaults standardUserDefaults] setInteger:selection forKey:kProjectMMeshQuality];

	if (_visualPluginData && _visualPluginData->pm) {
		if (selection == 0) {
			// Auto/Adaptive
			_visualPluginData->adaptiveMeshEnabled = true;
		} else {
			// Manual: 1=high(0), 2=medium(1), 3=low(2)
			int level = (int)(selection - 1);
			_visualPluginData->adaptiveMeshEnabled = false;
			_visualPluginData->meshQualityLevel = level;
			projectm_set_mesh_size(_visualPluginData->pm, kMeshSizes[level][0], kMeshSizes[level][1]);
		}
	}
}

- (void)presetDurationChanged:(NSSlider *)sender {
	double duration = sender.doubleValue;
	_presetDurationLabel.stringValue = [NSString stringWithFormat:@"%.0fs", duration];
	[[NSUserDefaults standardUserDefaults] setDouble:duration forKey:kProjectMPresetDuration];

	if (_visualPluginData && _visualPluginData->pm) {
		projectm_set_preset_duration(_visualPluginData->pm, duration);
	}
}

- (void)beatSensitivityChanged:(NSSlider *)sender {
	double sensitivity = sender.doubleValue;
	_beatSensitivityLabel.stringValue = [NSString stringWithFormat:@"%.1f", sensitivity];
	[[NSUserDefaults standardUserDefaults] setDouble:sensitivity forKey:kProjectMBeatSensitivity];

	if (_visualPluginData && _visualPluginData->pm) {
		projectm_set_beat_sensitivity(_visualPluginData->pm, (float)sensitivity);
	}
}

- (void)windowWillClose:(NSNotification *)notification {
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark -

void DrawVisual( VisualPluginData * visualPluginData )
{
	CGPoint where;

    VISUAL_PLATFORM_VIEW drawView = visualPluginData->subview;
    if (!visualPluginData->readyToDraw)
        return;

    // Measure actual FPS
    double currentTime = CACurrentMediaTime();
    if (visualPluginData->lastFrameTime > 0) {
        double deltaTime = currentTime - visualPluginData->lastFrameTime;
        if (deltaTime > 0) {
            double instantFPS = 1.0 / deltaTime;
            // Smooth with exponential moving average (0.1 = responsive, 0.01 = smooth)
            visualPluginData->measuredFPS = visualPluginData->measuredFPS * 0.9 + instantFPS * 0.1;
        }
    }
    visualPluginData->lastFrameTime = currentTime;

	glClearColor( 0.0, 0.0, 0.0, 0.0 );
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // render
    projectm_opengl_render_frame(visualPluginData->pm);

    glFlush();
    
    
    // TODO: artwork overlay
    
	// should we draw the info/artwork in the bottom-left corner?
	time_t		theTime = time( NULL );

	if ( theTime < visualPluginData->drawInfoTimeOut )
	{
		where = CGPointMake( 10, 10 );

		// if we have a song title, draw it (prefer the stream title over the regular name if we have it)
		NSString *				theString = NULL;

		if ( visualPluginData->streamInfo.streamTitle[0] != 0 )
			theString = [NSString stringWithCharacters:&visualPluginData->streamInfo.streamTitle[1] length:visualPluginData->streamInfo.streamTitle[0]];
		else if ( visualPluginData->trackInfo.name[0] != 0 )
			theString = [NSString stringWithCharacters:&visualPluginData->trackInfo.name[1] length:visualPluginData->trackInfo.name[0]];
		
		if ( theString != NULL )
		{
			NSDictionary *		attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor whiteColor], NSForegroundColorAttributeName, NULL];
			
			[theString drawAtPoint:where withAttributes:attrs];
		}

		// draw the artwork
		if ( visualPluginData->currentArtwork != NULL )
		{
			where.y += 20;

			[visualPluginData->currentArtwork drawAtPoint:where fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.75];
		}
	}
}


//-------------------------------------------------------------------------------------------------
//	UpdateArtwork
//-------------------------------------------------------------------------------------------------
//
void UpdateArtwork( VisualPluginData * visualPluginData, CFDataRef coverArt, UInt32 coverArtSize, UInt32 coverArtFormat )
{
	// release current image
	[visualPluginData->currentArtwork release];
	visualPluginData->currentArtwork = NULL;
	
	// create 100x100 NSImage* out of incoming CFDataRef if non-null (null indicates there is no artwork for the current track)
	if ( coverArt != NULL )
	{
		visualPluginData->currentArtwork = [[NSImage alloc] initWithData:(NSData *)coverArt];
		
		[visualPluginData->currentArtwork setSize:CGSizeMake( 100, 100 )];
	}
	
	UpdateInfoTimeOut( visualPluginData );
}

//-------------------------------------------------------------------------------------------------
//	InvalidateVisual
//-------------------------------------------------------------------------------------------------
//
void InvalidateVisual( VisualPluginData * visualPluginData )
{
	(void) visualPluginData;

#if USE_SUBVIEW
	// when using a custom subview, we invalidate it so we get our own draw calls
	[visualPluginData->subview setNeedsDisplay:YES];
#endif
}

//-------------------------------------------------------------------------------------------------
//	CreateVisualContext
//-------------------------------------------------------------------------------------------------
//
OSStatus ActivateVisual( VisualPluginData * visualPluginData, VISUAL_PLATFORM_VIEW destView, OptionBits options )
{
	OSStatus			status = noErr;

	visualPluginData->destView			= destView;
	visualPluginData->destRect			= [destView bounds];
	visualPluginData->destOptions		= options;
    visualPluginData->readyToDraw = false;

	UpdateInfoTimeOut( visualPluginData );

	if ([visualPluginData->destView respondsToSelector:@selector(setWantsBestResolutionOpenGLSurface:)]) {
	    [visualPluginData->destView setWantsBestResolutionOpenGLSurface:YES];
	}

#if USE_SUBVIEW

	// NSView-based subview
	visualPluginData->subview = [[VisualView alloc] initWithFrame:visualPluginData->destRect];
	if ( visualPluginData->subview != NULL )
	{
		[visualPluginData->subview setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
		[visualPluginData->subview setVisualPluginData:visualPluginData];
		if ([visualPluginData->subview respondsToSelector:@selector(setWantsBestResolutionOpenGLSurface:)]) {
		    [visualPluginData->subview setWantsBestResolutionOpenGLSurface:YES];
		}

		[destView addSubview:visualPluginData->subview];
	}
	else
	{
		status = memFullErr;
	}

    
    [[visualPluginData->subview openGLContext] makeCurrentContext];

    
#endif
    NSLog(@"activate visual");
    if (visualPluginData->pm == NULL) {
        
        NSBundle* me = [NSBundle bundleForClass: VisualView.class];
        NSLog(@"main bundle: %@", [me bundlePath]);
        NSString* presetsPath = [me pathForResource:@"presets" ofType:nil];
        NSLog(@"presets path %@", presetsPath);
        
        initProjectM(visualPluginData, std::string([presetsPath UTF8String]));
        
        // correctly size it
        ResizeVisual(visualPluginData);
    }
    
    NSLog(@"activated visual");
    
	return status;
}

//-------------------------------------------------------------------------------------------------
//	MoveVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus MoveVisual( VisualPluginData * visualPluginData, OptionBits newOptions )
{
    visualPluginData->destRect	  = [[NSScreen mainScreen] convertRectToBacking:([visualPluginData->subview bounds])];
	visualPluginData->destOptions = newOptions;

	return noErr;
}

//-------------------------------------------------------------------------------------------------
//	DeactivateVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus DeactivateVisual( VisualPluginData * visualPluginData )
{
#if USE_SUBVIEW
	[visualPluginData->subview removeFromSuperview];
	[visualPluginData->subview autorelease];
	visualPluginData->subview = NULL;
	[visualPluginData->currentArtwork release];
	visualPluginData->currentArtwork = NULL;
#endif

	visualPluginData->destView			= NULL;
	visualPluginData->destRect			= CGRectNull;
	visualPluginData->drawInfoTimeOut	= 0;
    visualPluginData->readyToDraw = false;

    if (visualPluginData->pm != NULL) {
        projectm_destroy(visualPluginData->pm);
        visualPluginData->pm = NULL;
    }
	
	return noErr;
}

//-------------------------------------------------------------------------------------------------
//	ResizeVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus ResizeVisual( VisualPluginData * visualPluginData )
{
    visualPluginData->destRect = [[NSScreen mainScreen] convertRectToBacking:([visualPluginData->subview bounds])];

    if (visualPluginData->pm != NULL) {
        projectm_set_window_size(visualPluginData->pm, visualPluginData->destRect.size.width, visualPluginData->destRect.size.height);
        NSLog(@"resized to %@ %@", [NSNumber numberWithDouble: visualPluginData->destRect.size.width], [NSNumber numberWithDouble: visualPluginData->destRect.size.height]);
        
        visualPluginData->readyToDraw = true;
    }

	return noErr;
}

//-------------------------------------------------------------------------------------------------
//	ConfigureVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus ConfigureVisual( VisualPluginData * visualPluginData )
{
	[[ProjectMSettingsPanel sharedPanel] showWithPluginData:visualPluginData];
	return noErr;
}

#pragma mark -

#if USE_SUBVIEW

@implementation VisualView

@synthesize visualPluginData = _visualPluginData;

- (id)initWithFrame:(NSRect)frame
{
    NSLog(@"initWithFrame called");
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] =
    {
        NSOpenGLPFAOpenGLProfile,
        NSOpenGLProfileVersion3_2Core,
        NSOpenGLPFAAccelerated,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
    if (pixelFormat == nil)
    {
        NSLog(@"Unable to create pixel format.");
        return self;
    }
    self = [super initWithFrame:frame pixelFormat:pixelFormat];
    if (self == nil)
    {
        NSLog(@"Unable to create an OpenGL context.");
        return self;
    }

    // Load VSync setting from preferences (default: disabled for performance measurement)
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL vsyncEnabled = [defaults objectForKey:kProjectMVSyncEnabled] ? [defaults boolForKey:kProjectMVSyncEnabled] : NO;
    GLint swapInterval = vsyncEnabled ? 1 : 0;
    [[self openGLContext] setValues:&swapInterval forParameter:NSOpenGLCPSwapInterval];

    // Enable layer backing so subviews render on top of OpenGL content
    [self setWantsLayer:YES];

    // Create FPS overlay label (hidden by default)
    // Use layer-backed view to render on top of OpenGL content
    _fpsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, frame.size.height - 30, 200, 20)];
    _fpsLabel.bezeled = NO;
    _fpsLabel.editable = NO;
    _fpsLabel.selectable = NO;
    _fpsLabel.drawsBackground = YES;
    _fpsLabel.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.6];
    _fpsLabel.textColor = [NSColor whiteColor];
    _fpsLabel.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightMedium];
    _fpsLabel.autoresizingMask = NSViewMinYMargin;  // Keep at top when resizing
    _fpsLabel.wantsLayer = YES;
    _fpsLabel.hidden = YES;
    [self addSubview:_fpsLabel positioned:NSWindowAbove relativeTo:nil];

    NSLog(@"super initWithFrame called");

    return self;
}

//-------------------------------------------------------------------------------------------------
//	isOpaque
//-------------------------------------------------------------------------------------------------
//
- (BOOL)isOpaque
{
	// your custom views should always be opaque or iTunes will waste CPU time drawing behind you
	return YES;
}

//-------------------------------------------------------------------------------------------------
//	drawRect
//-------------------------------------------------------------------------------------------------
//
-(void)drawRect:(NSRect)dirtyRect
{
	if ( _visualPluginData != NULL )
	{
		DrawVisual( _visualPluginData );
		[self updateFPSDisplay];
	}
}

//-------------------------------------------------------------------------------------------------
//	acceptsFirstResponder
//-------------------------------------------------------------------------------------------------
//
- (BOOL)acceptsFirstResponder
{
	return YES;
}

//-------------------------------------------------------------------------------------------------
//	becomeFirstResponder
//-------------------------------------------------------------------------------------------------
//
- (BOOL)becomeFirstResponder
{
	return YES;
}

//-------------------------------------------------------------------------------------------------
//	resignFirstResponder
//-------------------------------------------------------------------------------------------------
//
- (BOOL)resignFirstResponder
{
	return YES;
}

- (void)keyDown:(NSEvent *)event {
    // Handle key events for playlist navigation
    // Do not eat the space bar, ESC key, TAB key, or the arrow keys: iTunes reserves those keys.
    switch ([event keyCode]) {
        case kVK_Tab:
        case kVK_Space:
        case kVK_LeftArrow:
        case kVK_RightArrow:
        case kVK_UpArrow:
        case kVK_DownArrow:
        case kVK_Escape:
            [super keyDown:event];
            return;
        case kVK_ANSI_N: // 'n' for next preset
            if (_visualPluginData && _visualPluginData->playlist) {
                projectm_playlist_play_next(_visualPluginData->playlist, false);
            }
            return;
        case kVK_ANSI_P: // 'p' for previous preset
            if (_visualPluginData && _visualPluginData->playlist) {
                projectm_playlist_play_previous(_visualPluginData->playlist, false);
            }
            return;
        case kVK_ANSI_R: // 'r' for random preset
            if (_visualPluginData && _visualPluginData->playlist) {
                projectm_playlist_play_next(_visualPluginData->playlist, true);
            }
            return;
        case kVK_ANSI_L: // 'l' for lock/unlock preset
            if (_visualPluginData && _visualPluginData->pm) {
                bool locked = projectm_get_preset_locked(_visualPluginData->pm);
                projectm_set_preset_locked(_visualPluginData->pm, !locked);
            }
            return;
        case kVK_ANSI_F: // 'f' for FPS display toggle
            if (_visualPluginData) {
                _visualPluginData->showFPS = !_visualPluginData->showFPS;
                _fpsLabel.hidden = !_visualPluginData->showFPS;
                NSLog(@"FPS display toggled: %@", _visualPluginData->showFPS ? @"ON" : @"OFF");
            }
            return;
        case kVK_ANSI_0: // '0' for auto/adaptive quality
            if (_visualPluginData) {
                _visualPluginData->adaptiveMeshEnabled = true;
                NSLog(@"Mesh quality set to Auto (adaptive)");
            }
            return;
        case kVK_ANSI_1: // '1' for high quality mesh (disables adaptive)
            if (_visualPluginData && _visualPluginData->pm) {
                _visualPluginData->adaptiveMeshEnabled = false;
                _visualPluginData->meshQualityLevel = 0;
                projectm_set_mesh_size(_visualPluginData->pm, kMeshSizes[0][0], kMeshSizes[0][1]);
                NSLog(@"Mesh quality forced to High (%dx%d)", kMeshSizes[0][0], kMeshSizes[0][1]);
            }
            return;
        case kVK_ANSI_2: // '2' for medium quality mesh (disables adaptive)
            if (_visualPluginData && _visualPluginData->pm) {
                _visualPluginData->adaptiveMeshEnabled = false;
                _visualPluginData->meshQualityLevel = 1;
                projectm_set_mesh_size(_visualPluginData->pm, kMeshSizes[1][0], kMeshSizes[1][1]);
                NSLog(@"Mesh quality forced to Medium (%dx%d)", kMeshSizes[1][0], kMeshSizes[1][1]);
            }
            return;
        case kVK_ANSI_3: // '3' for low quality mesh (disables adaptive)
            if (_visualPluginData && _visualPluginData->pm) {
                _visualPluginData->adaptiveMeshEnabled = false;
                _visualPluginData->meshQualityLevel = 2;
                projectm_set_mesh_size(_visualPluginData->pm, kMeshSizes[2][0], kMeshSizes[2][1]);
                NSLog(@"Mesh quality forced to Low (%dx%d)", kMeshSizes[2][0], kMeshSizes[2][1]);
            }
            return;
        default:
            break;
    }
}

- (void)keyUp:(NSEvent *)event {
    [super keyUp:event];
}

- (void)updateFPSDisplay {
    if (_visualPluginData == NULL || _visualPluginData->pm == NULL || !_visualPluginData->showFPS) {
        return;
    }

    // Update FPS text using measured FPS (not projectM's target FPS)
    double fps = _visualPluginData->measuredFPS;
    int meshLevel = _visualPluginData->meshQualityLevel;
    NSString *qualityStr = (meshLevel == 0) ? @"High" : (meshLevel == 1) ? @"Med" : @"Low";
    NSString *modeStr = _visualPluginData->adaptiveMeshEnabled ? @"Auto" : @"Locked";
    [_fpsLabel setStringValue:[NSString stringWithFormat:@"%.1f FPS | %@: %@", fps, modeStr, qualityStr]];
}

@end

#endif	// USE_SUBVIEW

#pragma mark -

//-------------------------------------------------------------------------------------------------
//	GetVisualName
//-------------------------------------------------------------------------------------------------
//
void GetVisualName( ITUniStr255 name )
{
	CFIndex length = CFStringGetLength( kTVisualPluginName );

	name[0] = (UniChar)length;
	CFStringGetCharacters( kTVisualPluginName, CFRangeMake( 0, length ), &name[1] );
}

//-------------------------------------------------------------------------------------------------
//	GetVisualOptions
//-------------------------------------------------------------------------------------------------
//
OptionBits GetVisualOptions( void )
{
	OptionBits		options = (kVisualUsesOnly3D | kVisualWantsIdleMessages | kVisualWantsConfigure);

#if USE_SUBVIEW
	options |= kVisualUsesSubview;
#endif

	return options;
}

//-------------------------------------------------------------------------------------------------
//	iTunesPluginMainMachO
//-------------------------------------------------------------------------------------------------
//
OSStatus iTunesPluginMainMachO( OSType message, PluginMessageInfo * messageInfo, void * refCon )
{
	OSStatus		status;
	
	(void) refCon;
	
	switch ( message )
	{
		case kPluginInitMessage:
			status = RegisterVisualPlugin( messageInfo );
			break;
			
		case kPluginCleanupMessage:
			status = noErr;
			break;
			
		default:
			status = unimpErr;
			break;
	}
	
	return status;
}
