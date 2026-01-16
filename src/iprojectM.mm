// cross-platform iTunes plugin code, from the iTunes Visual SDK
// with additions for projectM support


#include "iprojectM.hpp"
#include "projectM-4/playlist.h"
#include <string.h>

// NSUserDefaults keys (must match iprojectM_mac.mm)
static NSString * const kProjectMMeshQuality = @"projectM.meshQuality";
static NSString * const kProjectMPresetDuration = @"projectM.presetDuration";
static NSString * const kProjectMBeatSensitivity = @"projectM.beatSensitivity";

// projectM
void initProjectM( VisualPluginData * visualPluginData, std::string presetPath ) {
    // Create projectM instance (requires valid OpenGL context)
    projectm_handle pm = projectm_create();
    if (pm == nullptr) {
        NSLog(@"Failed to create projectM instance");
        return;
    }

    // Load saved settings from NSUserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Mesh quality: 0=auto, 1=high, 2=medium, 3=low
    NSInteger meshQuality = [defaults objectForKey:kProjectMMeshQuality] ? [defaults integerForKey:kProjectMMeshQuality] : 0;

    // Configure mesh settings
    visualPluginData->framesAtCurrentLevel = 0;
    visualPluginData->frameCounter = 0;

    if (meshQuality == 0) {
        // Auto/Adaptive - start at highest quality
        visualPluginData->meshQualityLevel = 0;
        visualPluginData->adaptiveMeshEnabled = true;
        projectm_set_mesh_size(pm, kMeshSizes[0][0], kMeshSizes[0][1]);
    } else {
        // Manual quality: 1=high(0), 2=medium(1), 3=low(2)
        int level = (int)(meshQuality - 1);
        visualPluginData->meshQualityLevel = level;
        visualPluginData->adaptiveMeshEnabled = false;
        projectm_set_mesh_size(pm, kMeshSizes[level][0], kMeshSizes[level][1]);
    }

    // Detect display refresh rate for ProMotion displays
    UInt32 refreshRate = 60;
    if (@available(macOS 12.0, *)) {
        refreshRate = (UInt32)MIN([NSScreen.mainScreen maximumFramesPerSecond], 240);
    }
    visualPluginData->cachedRefreshRate = refreshRate;
    projectm_set_fps(pm, refreshRate);
    NSLog(@"Display refresh rate: %u Hz", refreshRate);

    projectm_set_soft_cut_duration(pm, 2.0);
    projectm_set_aspect_correction(pm, true);
    projectm_set_easter_egg(pm, 0.0f);

    // Load preset duration (default 30s)
    double presetDuration = [defaults objectForKey:kProjectMPresetDuration] ? [defaults doubleForKey:kProjectMPresetDuration] : 30.0;
    projectm_set_preset_duration(pm, presetDuration);

    // Load beat sensitivity (default 3.0)
    double beatSensitivity = [defaults objectForKey:kProjectMBeatSensitivity] ? [defaults doubleForKey:kProjectMBeatSensitivity] : 3.0;
    projectm_set_beat_sensitivity(pm, (float)beatSensitivity);

    // Set texture search paths
    const char* texturePaths[] = { presetPath.c_str() };
    projectm_set_texture_search_paths(pm, texturePaths, 1);

    NSLog(@"GL_VERSION: %s", glGetString(GL_VERSION));
    NSLog(@"GL_SHADING_LANGUAGE_VERSION: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    NSLog(@"GL_VENDOR: %s", glGetString(GL_VENDOR));

    visualPluginData->pm = pm;

    // Create playlist and add presets
    projectm_playlist_handle playlist = projectm_playlist_create(pm);
    if (playlist != nullptr) {
        projectm_playlist_add_path(playlist, presetPath.c_str(), true, false);
        projectm_playlist_set_shuffle(playlist, true);
        visualPluginData->playlist = playlist;

        // Start playing first preset
        if (projectm_playlist_size(playlist) > 0) {
            projectm_playlist_play_next(playlist, true);
        }
        NSLog(@"Playlist created with %u presets", projectm_playlist_size(playlist));
    } else {
        NSLog(@"Failed to create playlist");
    }
}

// Keyboard handling removed in projectM 4.x API
// Key events can be handled manually via playlist functions if needed

//-------------------------------------------------------------------------------------------------
//	AdaptMeshQuality
//-------------------------------------------------------------------------------------------------
// Dynamically adjusts mesh resolution based on FPS performance
//
void AdaptMeshQuality( VisualPluginData * visualPluginData )
{
    if (visualPluginData->pm == nullptr) {
        return;
    }

    // Skip if adaptive mesh is disabled (manually set via 1/2/3 keys)
    if (!visualPluginData->adaptiveMeshEnabled) {
        return;
    }

    // Only check every 60 frames (~0.5-1 sec depending on refresh rate)
    visualPluginData->frameCounter++;
    if (visualPluginData->frameCounter < 60) {
        return;
    }
    visualPluginData->frameCounter = 0;

    // Use measured FPS, not projectM's target FPS
    double fps = visualPluginData->measuredFPS;
    double target = (double)visualPluginData->cachedRefreshRate;
    int currentLevel = visualPluginData->meshQualityLevel;

    // If FPS drops below 80% of target, reduce quality immediately
    if (fps < target * 0.8 && currentLevel < kMeshQualityLevels - 1) {
        currentLevel++;
        projectm_set_mesh_size(visualPluginData->pm,
                               kMeshSizes[currentLevel][0],
                               kMeshSizes[currentLevel][1]);
        visualPluginData->meshQualityLevel = currentLevel;
        visualPluginData->framesAtCurrentLevel = 0;
        NSLog(@"Mesh quality reduced to level %d (%dx%d) - FPS: %.1f",
              currentLevel, kMeshSizes[currentLevel][0], kMeshSizes[currentLevel][1], fps);
    }
    // If FPS is consistently above 95% of target, consider raising quality
    else if (fps > target * 0.95 && currentLevel > 0) {
        visualPluginData->framesAtCurrentLevel++;
        // Wait ~2 seconds of sustained good performance before upgrading
        if (visualPluginData->framesAtCurrentLevel >= 4) {
            currentLevel--;
            projectm_set_mesh_size(visualPluginData->pm,
                                   kMeshSizes[currentLevel][0],
                                   kMeshSizes[currentLevel][1]);
            visualPluginData->meshQualityLevel = currentLevel;
            visualPluginData->framesAtCurrentLevel = 0;
            NSLog(@"Mesh quality raised to level %d (%dx%d) - FPS: %.1f",
                  currentLevel, kMeshSizes[currentLevel][0], kMeshSizes[currentLevel][1], fps);
        }
    } else {
        // Reset stability counter if FPS fluctuates
        visualPluginData->framesAtCurrentLevel = 0;
    }
}

void renderProjectMTexture( VisualPluginData * visualPluginData ){
    // this needs to be updated for gl3 (see SDL version)
#if 0
    static int textureHandle = visualPluginData->pm->initRenderToTexture();
    
    glClear(GL_COLOR_BUFFER_BIT);
    glClear(GL_DEPTH_BUFFER_BIT);
    
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glFrustum(-1, 1, -1, 1, 2, 10);
    
    glEnable(GL_DEPTH_TEST);
    
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
    glEnable(GL_TEXTURE_2D);
    glMatrixMode(GL_TEXTURE);
    glLoadIdentity();
    
    glBindTexture(GL_TEXTURE_2D, textureHandle);
    glColor4d(1.0, 1.0, 1.0, 1.0);
    
    glBegin(GL_QUADS);
    glTexCoord2d(0, 1);
    glVertex3d(-0.8, 0.8, 0);
    glTexCoord2d(0, 0);
    glVertex3d(-0.8, -0.8, 0);
    glTexCoord2d(1, 0);
    glVertex3d(0.8, -0.8, 0);
    glTexCoord2d(1, 1);
    glVertex3d(0.8, 0.8, 0);
    glEnd();
    
    glDisable(GL_TEXTURE_2D);
    
    glMatrixMode(GL_MODELVIEW);
    glDisable(GL_DEPTH_TEST);
#endif
}

//-------------------------------------------------------------------------------------------------
// ProcessRenderData
//-------------------------------------------------------------------------------------------------
//
void ProcessRenderData( VisualPluginData * visualPluginData, UInt32 timeStampID, const RenderVisualData * renderData )
{
    projectm_handle  pm = visualPluginData->pm;

	visualPluginData->renderTimeStampID	= timeStampID;

	if (renderData == nullptr)
	{
		memset( &visualPluginData->renderData, 0, sizeof(visualPluginData->renderData) );
		return;
	}

	visualPluginData->renderData = *renderData;

	if (pm == nullptr)
	{
	    return;
	}

	// Interleave audio data from the two channel buffers
	UInt8 interleavedData[kVisualNumWaveformEntries][kVisualMaxDataChannels];
	for (auto sample = 0; sample < kVisualNumWaveformEntries; sample++)
	{
	    interleavedData[sample][0] = renderData->waveformData[0][sample];
	    interleavedData[sample][1] = renderData->waveformData[1][sample];
	}

    // pass waveform data to projectM
    projectm_pcm_add_uint8(pm, &interleavedData[0][0],512, PROJECTM_STEREO);
}

//-------------------------------------------------------------------------------------------------
//	ResetRenderData
//-------------------------------------------------------------------------------------------------
//
void ResetRenderData( VisualPluginData * visualPluginData )
{
	memset( &visualPluginData->renderData, 0, sizeof(visualPluginData->renderData) );
}

//-------------------------------------------------------------------------------------------------
//	UpdateInfoTimeOut
//-------------------------------------------------------------------------------------------------
//
void UpdateInfoTimeOut( VisualPluginData * visualPluginData )
{
	// reset the timeout value we will use to show the info/artwork if we have it during DrawVisual()
	visualPluginData->drawInfoTimeOut = time( NULL ) + kInfoTimeOutInSeconds;
}

//-------------------------------------------------------------------------------------------------
//	UpdatePulseRate
//-------------------------------------------------------------------------------------------------
//
void UpdatePulseRate( VisualPluginData * visualPluginData, UInt32 * ioPulseRate )
{
	// vary the pulse rate based on whether or not iTunes is currently playing
	if ( visualPluginData->playing ) {
		// Use cached refresh rate (set during activation)
		*ioPulseRate = visualPluginData->cachedRefreshRate ? visualPluginData->cachedRefreshRate : kPlayingPulseRateInHz;
	} else {
		*ioPulseRate = kStoppedPulseRateInHz;
	}
}

//-------------------------------------------------------------------------------------------------
//	UpdateTrackInfo
//-------------------------------------------------------------------------------------------------
//
void UpdateTrackInfo( VisualPluginData * visualPluginData, ITTrackInfo * trackInfo, ITStreamInfo * streamInfo )
{
	if ( trackInfo != NULL )
		visualPluginData->trackInfo = *trackInfo;
	else
		memset( &visualPluginData->trackInfo, 0, sizeof(visualPluginData->trackInfo) );

	if ( streamInfo != NULL )
		visualPluginData->streamInfo = *streamInfo;
	else
		memset( &visualPluginData->streamInfo, 0, sizeof(visualPluginData->streamInfo) );

	UpdateInfoTimeOut( visualPluginData );
}

//-------------------------------------------------------------------------------------------------
//	RequestArtwork
//-------------------------------------------------------------------------------------------------
//
static void RequestArtwork( VisualPluginData * visualPluginData )
{
	// only request artwork if this plugin is active
	if ( visualPluginData->destView != NULL )
	{
		OSStatus		status;

		status = PlayerRequestCurrentTrackCoverArt( visualPluginData->appCookie, visualPluginData->appProc );
	}
}

//-------------------------------------------------------------------------------------------------
//	PulseVisual
//-------------------------------------------------------------------------------------------------
//
void PulseVisual( VisualPluginData * visualPluginData, UInt32 timeStampID, const RenderVisualData * renderData, UInt32 * ioPulseRate )
{
	// update internal state
	ProcessRenderData( visualPluginData, timeStampID, renderData );

	// if desired, adjust the pulse rate
	UpdatePulseRate( visualPluginData, ioPulseRate );

	// dynamically adjust mesh quality based on performance
	AdaptMeshQuality( visualPluginData );
}

//-------------------------------------------------------------------------------------------------
//	VisualPluginHandler
//-------------------------------------------------------------------------------------------------
//
static OSStatus VisualPluginHandler(OSType message,VisualPluginMessageInfo *messageInfo, void *refCon)
{
	OSStatus			status;
	VisualPluginData *	visualPluginData;

	visualPluginData = (VisualPluginData*) refCon;
	
	status = noErr;

	switch ( message )
	{
		/*
			Sent when the visual plugin is registered.  The plugin should do minimal
			memory allocations here.
		*/		
		case kVisualPluginInitMessage:
		{
			visualPluginData = (VisualPluginData *)calloc( 1, sizeof(VisualPluginData) );
			if ( visualPluginData == NULL )
			{
				status = memFullErr;
				break;
			}

			visualPluginData->appCookie	= messageInfo->u.initMessage.appCookie;
			visualPluginData->appProc	= messageInfo->u.initMessage.appProc;

			messageInfo->u.initMessage.refCon = (void *)visualPluginData;
			break;
		}
		/*
			Sent when the visual plugin is unloaded.
		*/		
		case kVisualPluginCleanupMessage:
		{
			if ( visualPluginData != NULL ) {
                if (visualPluginData->playlist) {
                    projectm_playlist_destroy(visualPluginData->playlist);
                    visualPluginData->playlist = NULL;
                }
                if (visualPluginData->pm) {
                    projectm_destroy(visualPluginData->pm);
                    visualPluginData->pm = NULL;
                }
				free( visualPluginData );
            }
			break;
		}
		/*
			Sent when the visual plugin is enabled/disabled.  iTunes currently enables all
			loaded visual plugins at launch.  The plugin should not do anything here.
		*/
		case kVisualPluginEnableMessage:
		case kVisualPluginDisableMessage:
		{
			break;
		}
		/*
			Sent if the plugin requests idle messages.  Do this by setting the kVisualWantsIdleMessages
			option in the RegisterVisualMessage.options field.
			
			DO NOT DRAW in this routine.  It is for updating internal state only.
		*/
		case kVisualPluginIdleMessage:
		{
			break;
		}			
		/*
			Sent if the plugin requests the ability for the user to configure it.  Do this by setting
			the kVisualWantsConfigure option in the RegisterVisualMessage.options field.
		*/
		case kVisualPluginConfigureMessage:
		{
			status = ConfigureVisual( visualPluginData );
			break;
		}
		/*
			Sent when iTunes is going to show the visual plugin.  At this
			point, the plugin should allocate any large buffers it needs.
		*/
		case kVisualPluginActivateMessage:
		{
			status = ActivateVisual( visualPluginData, messageInfo->u.activateMessage.view, messageInfo->u.activateMessage.options );

			// note: do not draw here if you can avoid it, a draw message will be sent as soon as possible
			
			if ( status == noErr )
				RequestArtwork( visualPluginData );
			break;
		}	
		/*
			Sent when this visual is no longer displayed.
		*/
		case kVisualPluginDeactivateMessage:
		{
			UpdateTrackInfo( visualPluginData, NULL, NULL );

			status = DeactivateVisual( visualPluginData );
			break;
		}
		/*
			Sent when iTunes is moving the destination view to a new parent window (e.g. to/from fullscreen).
		*/
		case kVisualPluginWindowChangedMessage:
		{
			status = MoveVisual( visualPluginData, messageInfo->u.windowChangedMessage.options );
			break;
		}
		/*
			Sent when iTunes has changed the rectangle of the currently displayed visual.
			
			Note: for custom NSView subviews, the subview's frame is automatically resized.
		*/
		case kVisualPluginFrameChangedMessage:
		{
			status = ResizeVisual( visualPluginData );
			break;
		}
		/*
			Sent for the visual plugin to update its internal animation state.
			Plugins are allowed to draw at this time but it is more efficient if they
			wait until the kVisualPluginDrawMessage is sent OR they simply invalidate
			their own subview.  The pulse message can be sent faster than the system
			will allow drawing to support spectral analysis-type plugins but drawing
			will be limited to the system refresh rate.
		*/
		case kVisualPluginPulseMessage:
		{
			PulseVisual( visualPluginData,
						 messageInfo->u.pulseMessage.timeStampID,
						 messageInfo->u.pulseMessage.renderData,
						 &messageInfo->u.pulseMessage.newPulseRateInHz );

            // Invalidate visual seems to lag a few frames behind, so let's draw as soon as possible
            DrawVisual( visualPluginData );

            // Update FPS overlay if visible
            if (visualPluginData->showFPS && visualPluginData->subview) {
                [visualPluginData->subview performSelector:@selector(updateFPSDisplay)];
            }
//            InvalidateVisual( visualPluginData );
			break;
		}
		/*
			It's time for the plugin to draw a new frame.
			
			For plugins using custom subviews, you should ignore this message and just
			draw in your view's draw method.  It will never be called if your subview 
			is set up properly.
		*/
		case kVisualPluginDrawMessage:
		{
#if !USE_SUBVIEW
            // Now drawing in kVisualPluginPulseMessage  -revmischa 09/14
            DrawVisual( visualPluginData );
#endif
			break;
		}
		/*
			Sent when the player starts.
		*/
		case kVisualPluginPlayMessage:
		{
			visualPluginData->playing = true;
			
			UpdateTrackInfo( visualPluginData, messageInfo->u.playMessage.trackInfo, messageInfo->u.playMessage.streamInfo );
		
			RequestArtwork( visualPluginData );
			
			InvalidateVisual( visualPluginData );
			break;
		}
		/*
			Sent when the player changes the current track information.  This
			is used when the information about a track changes.
		*/
		case kVisualPluginChangeTrackMessage:
		{
			UpdateTrackInfo( visualPluginData, messageInfo->u.changeTrackMessage.trackInfo, messageInfo->u.changeTrackMessage.streamInfo );

			RequestArtwork( visualPluginData );
				
			InvalidateVisual( visualPluginData );
			break;
		}
		/*
			Artwork for the currently playing song is being delivered per a previous request.
			
			Note that NULL for messageInfo->u.coverArtMessage.coverArt means the currently playing song has no artwork.
		*/
		case kVisualPluginCoverArtMessage:
		{
			UpdateArtwork(	visualPluginData,
							messageInfo->u.coverArtMessage.coverArt,
							messageInfo->u.coverArtMessage.coverArtSize,
							messageInfo->u.coverArtMessage.coverArtFormat );
			
			InvalidateVisual( visualPluginData );
			break;
		}
		/*
			Sent when the player stops or pauses.
		*/
		case kVisualPluginStopMessage:
		{
			visualPluginData->playing = false;
			
			ResetRenderData( visualPluginData );

			InvalidateVisual( visualPluginData );
			break;
		}
		/*
			Sent when the player changes the playback position.
		*/
		case kVisualPluginSetPositionMessage:
		{
			break;
		}
		default:
		{
			status = unimpErr;
			break;
		}
	}

	return status;	
}

//-------------------------------------------------------------------------------------------------
//	RegisterVisualPlugin
//-------------------------------------------------------------------------------------------------
//
OSStatus RegisterVisualPlugin( PluginMessageInfo * messageInfo )
{
	PlayerMessageInfo	playerMessageInfo;
	OSStatus			status;
		
	memset( &playerMessageInfo.u.registerVisualPluginMessage, 0, sizeof(playerMessageInfo.u.registerVisualPluginMessage) );

	GetVisualName( playerMessageInfo.u.registerVisualPluginMessage.name );

	SetNumVersion( &playerMessageInfo.u.registerVisualPluginMessage.pluginVersion, kTVisualPluginMajorVersion, kTVisualPluginMinorVersion, kTVisualPluginReleaseStage, kTVisualPluginNonFinalRelease );

	playerMessageInfo.u.registerVisualPluginMessage.options					= GetVisualOptions();
	playerMessageInfo.u.registerVisualPluginMessage.handler					= (VisualPluginProcPtr)VisualPluginHandler;
	playerMessageInfo.u.registerVisualPluginMessage.registerRefCon			= 0;
	playerMessageInfo.u.registerVisualPluginMessage.creator					= kTVisualPluginCreator;
	
	playerMessageInfo.u.registerVisualPluginMessage.pulseRateInHz			= kStoppedPulseRateInHz;	// update my state N times a second
	playerMessageInfo.u.registerVisualPluginMessage.numWaveformChannels		= 2;
	playerMessageInfo.u.registerVisualPluginMessage.numSpectrumChannels		= 2;
	
	playerMessageInfo.u.registerVisualPluginMessage.minWidth				= 64;
	playerMessageInfo.u.registerVisualPluginMessage.minHeight				= 64;
	playerMessageInfo.u.registerVisualPluginMessage.maxWidth				= 0;	// no max width limit
	playerMessageInfo.u.registerVisualPluginMessage.maxHeight				= 0;	// no max height limit
	
	status = PlayerRegisterVisualPlugin( messageInfo->u.initMessage.appCookie, messageInfo->u.initMessage.appProc, &playerMessageInfo );
    
	return status;
}
