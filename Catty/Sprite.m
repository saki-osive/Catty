//
//  CattyAppDelegate.m
//  Catty
//
//  Created by Christof Stromberger on 07.07.12.
//  Copyright (c) 2012 Graz University of Technology. All rights reserved.
//

#import "SpriteManagerDelegate.h"
#import "Brick.h"
#import "Sprite.h"
#import "Costume.h"
#import "Sound.h"
#import "Script.h"
#import "WhenScript.h"
#import "Util.h"
#import "enums.h"


// need CattyViewController to access FRAMES_PER_SECOND    TODO: change
#import "CattyViewController.h"

//test
#import "CattyAppDelegate.h"


typedef struct {
    CGPoint geometryVertex;
    CGPoint textureVertex;
} TexturedVertex;

typedef struct {
    TexturedVertex bottomLeftCorner;
    TexturedVertex bottomRightCorner;
    TexturedVertex topLeftCorner;
    TexturedVertex topRightCorner;
} TexturedQuad;



//////////////////////////////////////////////////////////////////////////////////////////

// TODO: change this to struct????? Maybe??!?!?!?

@implementation PositionAtTime
@synthesize position = _position;
@synthesize timestamp = _timestamp;
+(PositionAtTime*)positionAtTimeWithPosition:(GLKVector3)position andTimestamp:(double)timestamp
{
    PositionAtTime *obj = [[PositionAtTime alloc]init];
    obj.position = position;
    obj.timestamp = timestamp;
    return obj;
}
@end

//////////////////////////////////////////////////////////////////////////////////////////



@interface Sprite()

@property (assign) TexturedQuad quad;
@property (nonatomic, strong) GLKTextureInfo *textureInfo;

@property (assign, nonatomic) GLKVector3 position;        // position - origin is in the middle of the sprite

@property (assign, nonatomic) float scaleFactor;    // scale image to fit screen
@property (assign, nonatomic) float scaleWidth;     // scale width  of image according to bricks (e.g. SetSizeTo-brick)
@property (assign, nonatomic) float scaleHeight;    // scale height of image according to bricks (e.g. SetSizeTo-brick)

@property (assign, nonatomic) float xOffset;        // black border, if proportions are different (project-xml-resolution vs. screen-resolution)
@property (assign, nonatomic) float yOffset;



@property (nonatomic, strong) NSMutableArray *activeScripts;
@property (strong, nonatomic) NSMutableDictionary *nextPositions;       //key=script   value=positionAtTime

@property (strong, nonatomic) NSNumber *indexOfCurrentCostumeInArray;

@property (strong, nonatomic) NSArray *costumesArray;    // tell the compiler: "I want a private setter"
@property (strong, nonatomic) NSArray *soundsArray;
@property (strong, nonatomic) NSArray *startScriptsArray;
@property (strong, nonatomic) NSArray *whenScriptsArray;
@property (strong, nonatomic) NSDictionary *broadcastScripts;

@property (assign, nonatomic) float alphaValue;

@property (assign, nonatomic) BOOL showSprite;

@end

@implementation Sprite

// public synthesizes
@synthesize spriteManagerDelegate = _spriteManagerDelegate;
@synthesize name = _name;
@synthesize projectPath = _projectPath;
@synthesize costumesArray = _costumesArray;
@synthesize soundsArray = _soundsArray;
@synthesize startScriptsArray = _startScriptsArray;
@synthesize whenScriptsArray = _whenScriptsArray;
@synthesize broadcastScripts = _broadcastScripts;
@synthesize position = _position;
@synthesize contentSize = _contentSize;
@synthesize effect = _effect;

// private synthesizes
@synthesize scaleFactor = _scaleFactor;
@synthesize scaleWidth  = _scaleWidth;
@synthesize scaleHeight = _scaleHeight;
@synthesize xOffset = _xOffset;
@synthesize yOffset = _yOffset;
@synthesize quad = _quad;
@synthesize textureInfo = _textureInfo;
@synthesize activeScripts = _activeScripts;
@synthesize nextPositions = _nextPositions;
@synthesize indexOfCurrentCostumeInArray = _indexOfCurrentCostumeInArray;
@synthesize showSprite = _showSprite;
@synthesize alphaValue = _alphaValue;




#pragma mark Custom getter and setter
- (NSArray*)costumesArray
{
    if (_costumesArray == nil)
        _costumesArray = [[NSArray alloc] init];

    return _costumesArray;
}

- (NSArray*)soundsArray
{
    if (_soundsArray == nil)
        _soundsArray = [[NSArray alloc] init];
    
    return _soundsArray;
}

- (NSArray*)startScriptsArray
{
    if (_startScriptsArray == nil)
        _startScriptsArray = [[NSArray alloc] init];
    
    return _startScriptsArray;
}

- (NSArray*)whenScriptsArray
{
    if (_whenScriptsArray == nil)
        _whenScriptsArray = [[NSArray alloc] init];
    
    return _whenScriptsArray;
}

-(NSDictionary *)broadcastScripts
{
    if (_broadcastScripts == nil)
        _broadcastScripts = [[NSDictionary alloc] init];
    
    return _broadcastScripts;
}

- (NSMutableDictionary*)nextPositions
{
    if (!_nextPositions)
        _nextPositions = [[NSMutableDictionary alloc]init];
    
    return _nextPositions;
}


#pragma mark - init methods
- (id)init
{
    if (self = [super init]) 
    {
        _position = GLKVector3Make(0, 0, 0); //todo: change z index
        self.showSprite = YES;
        self.scaleFactor = 1.0f;
        self.scaleWidth  = 1.0f;
        self.scaleHeight = 1.0f;
        self.activeScripts = [[NSMutableArray alloc]init];
        self.alphaValue = 1.0f;
//        self.indexOfCurrentCostumeInArray = [NSNumber numberWithInt:-1];
    }
    return self;
}

- (id)initWithEffect:(GLKBaseEffect*)effect
{
    self = [super init];
    if (self)
    {
        self.effect = effect;
        self.showSprite = YES;
        self.scaleFactor = 1.0f;
        self.scaleWidth  = 1.0f;
        self.scaleHeight = 1.0f;
        self.activeScripts = [[NSMutableArray alloc]init];
        self.alphaValue = 1.0f;
//        self.indexOfCurrentCostumeInArray = [NSNumber numberWithInt:-1];
    }
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

-(void)setProjectResolution:(CGSize)projectResolution
{    
    float scaleX = [UIScreen mainScreen].bounds.size.width  / projectResolution.width;
    float scaleY = [UIScreen mainScreen].bounds.size.height / projectResolution.height;
    if (scaleY < scaleX)
        self.scaleFactor = scaleY;
    
    self.xOffset = ([UIScreen mainScreen].bounds.size.width  - (projectResolution.width  * self.scaleFactor)) / 2.0f;
    self.yOffset = ([UIScreen mainScreen].bounds.size.height - (projectResolution.height * self.scaleFactor)) / 2.0f;
    
    if (projectResolution.width == 0)
        self.xOffset = -1;
    if (projectResolution.height == 0)
        self.yOffset = -1;
    
    NSLog(@"Scale screen size:");
    NSLog(@"  Device:    %f / %f", [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    NSLog(@"  Project:   %f / %f", projectResolution.width, projectResolution.height);
    NSLog(@"  Scale-Factor: %f", self.scaleFactor);
}

- (void)addCostume:(Costume *)costume
{
    self.costumesArray = [self.costumesArray arrayByAddingObject:costume];
}

- (void)addCostumes:(NSArray *)costumesArray
{
    self.costumesArray = [self.costumesArray arrayByAddingObjectsFromArray:costumesArray];
}


- (void)addStartScript:(StartScript *)script
{
    self.startScriptsArray = [self.startScriptsArray arrayByAddingObject:script];
}

- (void)addWhenScript:(WhenScript *)script
{
    self.whenScriptsArray = [self.whenScriptsArray arrayByAddingObject:script];
}

- (void)addBroadcastScript:(Script *)script forMessage:(NSString *)message
{
    NSMutableDictionary *mutableDictionary = [self.broadcastScripts mutableCopy];
    [mutableDictionary setObject:script forKey:message];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(performBroadcastScript:) name:message object:nil];
    self.broadcastScripts = [NSDictionary dictionaryWithDictionary:mutableDictionary];
}

- (float)getZIndex
{
    // TODO: change this - z-coord is not valid
    return self.position.z;
}

-(void)setZIndex:(float)newZIndex
{
    self.position = GLKVector3Make(self.position.x, self.position.y, newZIndex);
}

-(void)decrementZIndexByOne
{
    [self setZIndex:self.position.z-1];
}

-(void)stopAllSounds
{
    [self.spriteManagerDelegate stopAllSounds];
}

#pragma mark - costume index SETTER
- (void)setIndexOfCurrentCostumeInArray:(NSNumber*)indexOfCurrentCostumeInArray
{
    _indexOfCurrentCostumeInArray = indexOfCurrentCostumeInArray;
    
    if (_indexOfCurrentCostumeInArray.intValue < 0)
        return;
    
    NSLog(@"Try to load costume %d / %d", indexOfCurrentCostumeInArray.intValue, [self.costumesArray count]);
    
    if ([self.costumesArray count] - 1 < indexOfCurrentCostumeInArray.intValue) {
        NSLog(@"Index %d is invalid! Array-size: %d", indexOfCurrentCostumeInArray.intValue, [self.costumesArray count]);
    }
    
    NSString *fileName = ((Costume*)[self.costumesArray objectAtIndex:[self.indexOfCurrentCostumeInArray intValue]]).costumeFileName;
    
    NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithBool:YES],
                              GLKTextureLoaderOriginBottomLeft, 
                              nil];
    
    NSError *error;    
    //NSString *path = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
//    NSBundle *bundle = [NSBundle bundleForClass:[CattyAppDelegate class]];
//    NSString *path = [bundle pathForResource:fileName ofType:nil];
    
//    
//    
//    NSString *mainBundlePath = [[NSBundle mainBundle] resourcePath];
//    NSString *directBundlePath = [[NSBundle bundleForClass:[self class]] resourcePath];
//    NSLog(@"Main Bundle Path: %@", mainBundlePath);
//    NSLog(@"Direct Path: %@", directBundlePath);
//    NSString *mainBundleResourcePath = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
//    NSString *directBundleResourcePath = [[NSBundle bundleForClass:[self class]] pathForResource:fileName ofType:nil];
//    NSLog(@"Main Bundle Path: %@", mainBundleResourcePath);
//    NSLog(@"Direct Path: %@", directBundleResourcePath);    
    
    
//    NSString *newPath = [NSString stringWithFormat:@"%@/imageToLoadNow.png", [path stringByDeletingLastPathComponent]];
//    [[NSFileManager defaultManager] moveItemAtPath:path toPath:newPath error:&error];
//    NSLog(@"Error filemanager: %@", [error localizedDescription]);
//    
//    
    
    NSLog(@"Filename: %@", fileName);
    
    //NSString *pathToImage = [NSString stringWithFormat:@"%@/defaultProject/images/%@", [Util applicationDocumentsDirectory], fileName];
//    NSString *path = [NSString stringWithFormat:@"/%@/%@/%@", self.projectName, SPRITE_IMAGE_FOLDER, fileName];
//    NSString *pathToImage = [[NSBundle mainBundle] pathForResource:path ofType:nil];

    NSString *pathToImage = [NSString stringWithFormat:@"%@images/%@", self.projectPath, fileName]; // TODO: change const string
    
    NSLog(@"Try to load image: %@", pathToImage);
    
    self.textureInfo = [GLKTextureLoader textureWithContentsOfFile:pathToImage options:options error:&error];
    if (self.textureInfo == nil) 
    {
        NSLog(@"Error loading file: %@", [error localizedDescription]);
        return;
    }

    [self setSpriteSize];
//    [self setSpriteSizeWithWidth:self.textureInfo.width andHeight:self.textureInfo.height];
    
//    self.contentSize = CGSizeMake(self.textureInfo.width, self.textureInfo.height);
//    
//    //test
////    CGFloat width = [UIScreen mainScreen].bounds.size.width;
////    CGFloat height = [UIScreen mainScreen].bounds.size.height;
////    NSLog(@"self width: %f", self.contentSize.width/2);
////    NSLog(@"width: %f, newWidth: %f", width/2, (width/2 - self.contentSize.width/2));
////    self.position = GLKVector3Make((width/2 - self.contentSize.width/2), (height/2 - self.contentSize.height/2), 0);
//    //end of test
//    
//    
//    TexturedQuad newQuad;
//    newQuad.bottomLeftCorner.geometryVertex = CGPointMake(0, 0);
//    newQuad.bottomRightCorner.geometryVertex = CGPointMake(self.textureInfo.width, 0);
//    newQuad.topLeftCorner.geometryVertex = CGPointMake(0, self.textureInfo.height);
//    newQuad.topRightCorner.geometryVertex = CGPointMake(self.textureInfo.width, self.textureInfo.height);
//
//    newQuad.bottomLeftCorner.textureVertex = CGPointMake(0, 0);
//    newQuad.bottomRightCorner.textureVertex = CGPointMake(1, 0);
//    newQuad.topLeftCorner.textureVertex = CGPointMake(0, 1);
//    newQuad.topRightCorner.textureVertex = CGPointMake(1, 1);
//    self.quad = newQuad;
}

-(void)setSpriteSize//WithWidth:(float)width andHeight:(float)height
{
    float width  = self.textureInfo.width  * self.scaleWidth;
    float height = self.textureInfo.height * self.scaleHeight;
        
    self.contentSize = CGSizeMake(width, height);
    
    width  *= self.scaleFactor;
    height *= self.scaleFactor;
    
    
    TexturedQuad newQuad;
    newQuad.bottomLeftCorner.geometryVertex = CGPointMake(0, 0);
    newQuad.bottomRightCorner.geometryVertex = CGPointMake(width, 0);
    newQuad.topLeftCorner.geometryVertex = CGPointMake(0, height);
    newQuad.topRightCorner.geometryVertex = CGPointMake(width, height);
    
    newQuad.bottomLeftCorner.textureVertex = CGPointMake(0, 0);
    newQuad.bottomRightCorner.textureVertex = CGPointMake(1, 0);
    newQuad.topLeftCorner.textureVertex = CGPointMake(0, 1);
    newQuad.topRightCorner.textureVertex = CGPointMake(1, 1);
    self.quad = newQuad;
}

- (GLKMatrix4) modelMatrix 
{
    GLKMatrix4 modelMatrix = GLKMatrix4Identity;
    //    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    //    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    //    NSLog(@"self width: %f", self.contentSize.width/2);
    //    NSLog(@"width: %f, newWidth: %f", width/2, (width/2 - self.contentSize.width/2));
    //    self.position = GLKVector3Make((width/2 - self.contentSize.width/2), (height/2 - self.contentSize.height/2), 0);

    float x = (self.position.x * self.scaleFactor) + [UIScreen mainScreen].bounds.size.width/2;
    float y = (self.position.y * self.scaleFactor) + [UIScreen mainScreen].bounds.size.height/2;
        
//    NSLog(@"x/y: %f/%f", x, y);
    
    CGSize scaledContentSize = CGSizeMake(self.contentSize.width * self.scaleFactor, self.contentSize.height * self.scaleFactor);
    
    modelMatrix = GLKMatrix4Translate(modelMatrix, x, y, self.position.z);
    modelMatrix = GLKMatrix4Translate(modelMatrix, -scaledContentSize.width/2, -scaledContentSize.height/2, 0);
    
    return modelMatrix;
}

#pragma mark - graphics
- (void)update:(float)dt
{
    NSTimeInterval now = [[NSDate date]timeIntervalSince1970];
    
    for (PositionAtTime *nextPosition in [self.nextPositions allValues]) {
        
        if (now >= nextPosition.timestamp) {
            Script *script = [[self.nextPositions allKeysForObject:nextPosition] lastObject];
            NSLog(@"remove nextPosition");            
            [self.nextPositions removeObjectForKey:script.description];
        
        } else {
        
            // calculate position
            double timeLeft = (nextPosition.timestamp - now);    // in sec
            int numberOfSteps = round(timeLeft * (float)FRAMES_PER_SECOND);               // TODO: find better way to determine FPS (e.g. GLKit-variable??)
            
            GLKVector3 direction = GLKVector3Subtract(nextPosition.position, self.position);
            
            GLKVector3 step = direction;
            if (numberOfSteps > 0)
                step = GLKVector3DivideScalar(direction, numberOfSteps);
            
            self.position = GLKVector3Add(self.position, step);
        }

    }
}

- (void)render
{
    if (self.showSprite)
    {
    
        if (!self.effect)
            NSLog(@"Sprite.m => render => NO effect set!!!");
    
        self.effect.texture2d0.name = self.textureInfo.name;
        self.effect.texture2d0.enabled = YES;
    
        
        //NSLog(@"Texture: %u", self.effect.texture2d0.name);
        
        self.effect.transform.modelviewMatrix = self.modelMatrix;
        
        
        self.effect.useConstantColor = YES;
        self.effect.constantColor = GLKVector4Make(255, 255, 255, self.alphaValue);
        
        
    
        [self.effect prepareToDraw];
    
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    
        long offset = (long)&_quad;
        glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, sizeof(TexturedVertex), (void *) (offset + offsetof(TexturedVertex, geometryVertex)));
        glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(TexturedVertex), (void *) (offset + offsetof(TexturedVertex, textureVertex)));
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
//        NSLog(@"render: %@   %f", self.name, self.position.z);
    }
}



//-(void)performNextBrickInQueue
//{
//    if ([self.brickQueue count] > 0)
//    {
//        [((Brick*)[self.brickQueue objectAtIndex:0]) performOnSprite:self];
//        [self.brickQueue removeObjectAtIndex:0];
//    }
//}


#pragma mark - actions

-(void)changeSizeTo:(CGSize)size
{
    //// TODO DIRTY!!!! Just for black frames.......!!!!
        
    self.contentSize = CGSizeMake(size.width, size.height);
    
    TexturedQuad newQuad;
    newQuad.bottomLeftCorner.geometryVertex = CGPointMake(0, 0);
    newQuad.bottomRightCorner.geometryVertex = CGPointMake(size.width, 0);
    newQuad.topLeftCorner.geometryVertex = CGPointMake(0, size.height);
    newQuad.topRightCorner.geometryVertex = CGPointMake(size.width, size.height);
    
    newQuad.bottomLeftCorner.textureVertex = CGPointMake(0, 0);
    newQuad.bottomRightCorner.textureVertex = CGPointMake(1, 0);
    newQuad.topLeftCorner.textureVertex = CGPointMake(0, 1);
    newQuad.topRightCorner.textureVertex = CGPointMake(1, 1);
    self.quad = newQuad;
}

-(void)placeAt:(GLKVector3)newPosition
{
    self.position = newPosition;
}

//- (void)wait:(int)durationInMilliSecs fromScript:(Script*)script
//{
////    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970] + (durationInMilliSecs/1000.0f);
////    
////    NSLog(@"now: %f     timestamp :%f", [[NSDate date]timeIntervalSince1970], timeStamp);
////    
////    [self.waitUntilForScripts setValue:[NSNumber numberWithFloat:timeStamp] forKey:script.description];    // TODO: whole description as key??
//}

- (void)glideToPosition:(GLKVector3)position withinDurationInMilliSecs:(int)durationInMilliSecs fromScript:(Script*)script
{
    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970] + (durationInMilliSecs/1000.0f);
    PositionAtTime *positionAtTime = [PositionAtTime positionAtTimeWithPosition:position andTimestamp:timeStamp];
    [self.nextPositions setValue:positionAtTime forKey:script.description];                 // TODO: whole description as key??
}

- (void)changeCostume:(NSNumber *)indexOfCostumeInArray
{
    self.indexOfCurrentCostumeInArray = indexOfCostumeInArray;
}

- (void)nextCostume
{
    if (self.indexOfCurrentCostumeInArray.intValue == [self.costumesArray count]-1)
        self.indexOfCurrentCostumeInArray = [NSNumber numberWithInt:0];
    else
        self.indexOfCurrentCostumeInArray = [NSNumber numberWithInt:self.indexOfCurrentCostumeInArray.intValue + 1];
}

- (void)hide
{
    self.showSprite = NO;
}

- (void)show
{
    self.showSprite = YES;
}

- (void)setXPosition:(float)xPosition
{
    self.position = GLKVector3Make(xPosition, self.position.y, self.position.z);
}

-(void)setYPosition:(float)yPosition
{
    self.position = GLKVector3Make(self.position.x, yPosition, self.position.z);
}

-(void)broadcast:(NSString *)message
{
    [[NSNotificationCenter defaultCenter] postNotificationName:message object:self];
}

-(void)broadcastAndWait:(NSString *)message
{
    
    // Does not work!
    
        NSLog(@"Now");
    
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        [[NSNotificationCenter defaultCenter] postNotificationName:message object:self];
//    });
}

-(void)comeToFront
{
    [self.spriteManagerDelegate bringToFrontSprite:self];
}

-(void)goNStepsBack:(int)n
{
    [self.spriteManagerDelegate bringNStepsBackSprite:self numberOfSteps:n];
}

-(void)changeSizeByN:(float)sizePercentageRate
{
    self.scaleWidth  += sizePercentageRate / 100.0f;
    self.scaleHeight += sizePercentageRate / 100.0f;
    
    [self setSpriteSize];
}

-(void)changeXBy:(int)x
{
    self.position = GLKVector3Make(self.position.x + x, self.position.y, self.position.z);
}

-(void)changeYBy:(int)y
{
    self.position = GLKVector3Make(self.position.x, self.position.y + y, self.position.z);
}


-(void)setSizeToPercentage:(float)sizeInPercentage
{
    self.scaleWidth  = sizeInPercentage / 100.0f;
    self.scaleHeight = sizeInPercentage / 100.0f;
    [self setSpriteSize];
}

//-(void)addLoopBricks:(NSArray *)bricks
//{
//    self.brickQueue = [NSMutableArray arrayWithArray:[bricks arrayByAddingObjectsFromArray:self.brickQueue]];
//}

-(void)setTransparency:(float)transparency
{
    self.alphaValue = (100.0f-transparency)/100.0f;
}

-(void)changeTransparencyBy:(float)increase
{
    self.alphaValue += increase;
}

- (void)addSound:(AVAudioPlayer *)player
{
    //[self.soundsArray addObject:player];
    //player.delegate = self;
    //[player play];
    
    [self.spriteManagerDelegate addSound:player forSprite:self];
}


- (void)setVolumeTo:(float)volume
{
    [self.spriteManagerDelegate setVolumeTo:volume forSprite:self];
}

-(void)changeVolumeBy:(float)percent
{
    [self.spriteManagerDelegate changeVolumeBy:percent forSprite:self];
}

#pragma mark - description
- (NSString*)description
{
    NSMutableString *ret = [[NSMutableString alloc] init];
    
    [ret appendFormat:@"Sprite (0x%x):\n", self];
    [ret appendFormat:@"\t\t\tName: %@\n", self.name];
    [ret appendFormat:@"\t\t\tPosition: [%f, %f, %f] (x, y, z)\n", self.position.x, self.position.y, self.position.z];
    [ret appendFormat:@"\t\t\tContent size: [%f, %f] (x, y)\n", self.contentSize.width, self.contentSize.height];
    [ret appendFormat:@"\t\t\tCostume index: %d\n", self.indexOfCurrentCostumeInArray.intValue];
    
    if ([self.costumesArray count] > 0)
    {
        [ret appendString:@"\t\t\tCostumes:\n"];
        for (Costume *costume in self.costumesArray)
        {
            [ret appendFormat:@"\t\t\t\t - %@\n", costume];
        }
    }
    else 
    {
        [ret appendString:@"\t\t\tCostumes: None\n"];
    }

    if ([self.soundsArray count] > 0)
    {
        [ret appendString:@"\t\t\tSounds\n"];
        for (Sound *sound in self.soundsArray)
        {
            [ret appendFormat:@"\t\t\t\t - %@\n", sound];
        }
    }
    else 
    {
        [ret appendString:@"\t\t\tSounds: None\n"];
    }

    
    //[ret appendFormat:@"\t\t\tCostumes: %@\n", self.costumesArray];
    //[ret appendFormat:@"\t\t\tSounds: %@\n", self.soundsArray];    
    
    return [[NSString alloc] initWithString:ret];
}


- (CGRect)boundingBox
{
    CGSize scaledContentSize = CGSizeMake(self.contentSize.width * self.scaleFactor, self.contentSize.height * self.scaleFactor);
    
//    float x = self.position.x + [UIScreen mainScreen].bounds.size.width/2 - scaledContentSize.width/2;
//    float y = self.position.y + [UIScreen mainScreen].bounds.size.height/2 - scaledContentSize.height/2;
    
    float x = self.position.x * self.scaleFactor + [UIScreen mainScreen].bounds.size.width /2.0f - scaledContentSize.width /2.0f;
    float y = self.position.y * self.scaleFactor + [UIScreen mainScreen].bounds.size.height/2.0f - scaledContentSize.height/2.0f;

    
    CGRect rect = CGRectMake(x, y, scaledContentSize.width, scaledContentSize.height);
    return rect;
}

#pragma mark - script methods
- (void)start
{
    //self.indexOfCurrentCostumeInArray = [NSNumber numberWithInt:0]; // TODO: maybe remove this line??

    for (Script *script in self.startScriptsArray)
    {
        [self.activeScripts addObject:script];
        
        // ------------------------------------------ THREAD --------------------------------------
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [script runScriptForSprite:self];
            
            // tell the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                [self scriptFinished:script];
            });
        });
        // ------------------------------------------ END -----------------------------------------
    }
}


- (void)touch:(TouchAction)type
{
    //todo: throw exception if its not a when script
    for (Script *script in self.whenScriptsArray)
    {
        NSLog(@"Performing script with action: %@", script.description);
        if (type == script.action)
        {
            if ([self.activeScripts containsObject:script]) {
                [script resetScript];
                [self.nextPositions removeObjectForKey:script.description];
            } else {
                [self.activeScripts addObject:script];
                
                // ------------------------------------------ THREAD --------------------------------------
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [script runScriptForSprite:self];
                    
                    // tell the main thread
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self scriptFinished:script];
                    });
                });
                // ------------------------------------------ END -----------------------------------------
            }
        }
    }
}

- (void)performBroadcastScript:(NSNotification*)notification
{
    Script *script = [self.broadcastScripts objectForKey:notification.name];
    if (script) {

        if ([self.activeScripts containsObject:script]) {
            [script resetScript];
            [self.nextPositions removeObjectForKey:script.description];
        } else {
            [self.activeScripts addObject:script];
            
            // -------- ---------------------------------- THREAD --------------------------------------
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [script runScriptForSprite:self];
                
                // tell the main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self scriptFinished:script];
                });
            });
            // ------------------------------------------ END -----------------------------------------
        }

    }
}

-(void)scriptFinished:(Script *)script
{
    [self.nextPositions removeObjectForKey:script.description];
    [self.activeScripts removeObject:script];
}

-(void)stopAllScripts
{
    for (Script *script in self.activeScripts) {
        [script stopScript];
    }
    self.nextPositions = nil;
    self.activeScripts = nil;
}

@end
