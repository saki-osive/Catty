//
//  CattyAppDelegate.m
//  Catty
//
//  Created by Christof Stromberger on 07.07.12.
//  Copyright (c) 2012 Graz University of Technology. All rights reserved.
//

#import "Sprite.h"
#import "Costume.h"
#import "Sound.h"
#import "Script.h"
#import "WhenScript.h"
#import "Util.h"

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


@interface Sprite()

@property (assign) TexturedQuad quad;
@property (nonatomic, strong) GLKTextureInfo *textureInfo;

@property (atomic, strong) NSMutableArray *nextPositions;

@end

@implementation Sprite

// public synthesizes
@synthesize name = _name;
@synthesize costumesArray = _costumesArray;
@synthesize soundsArray = _soundsArray;
@synthesize startScriptsArray = _startScriptsArray;
@synthesize whenScriptsArray = _whenScriptsArray;
@synthesize position = _position;
@synthesize contentSize = _contentSize;
@synthesize indexOfCurrentCostumeInArray = _indexOfCurrentCostumeInArray;
@synthesize effect = _effect;

// private synthesizes
@synthesize quad = _quad;
@synthesize textureInfo = _textureInfo;
@synthesize nextPositions = _nextPositions;

#pragma mark Custom getter and setter
- (NSMutableArray*)costumesArray
{
    if (_costumesArray == nil)
        _costumesArray = [[NSMutableArray alloc] init];

    return _costumesArray;
}

#pragma mark - init methods
- (id)init
{
    if (self = [super init]) 
    {
        _position = GLKVector3Make(0, 0, 0); //todo: change z index
    }
    return self;
}

- (id)initWithEffect:(GLKBaseEffect*)effect
{
    self = [super init];
    if (self)
    {
        self.effect = effect;
    }
    return self;
}


#pragma mark - costume index
- (void)setIndexOfCurrentCostumeInArray:(NSNumber*)indexOfCurrentCostumeInArray
{
    _indexOfCurrentCostumeInArray = indexOfCurrentCostumeInArray;
    
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
    
    
    NSString *pathToImage = [NSString stringWithFormat:@"%@/defaultProject/images/%@", [Util applicationDocumentsDirectory], fileName];
    NSLog(@"path: %@", pathToImage);
    self.textureInfo = [GLKTextureLoader textureWithContentsOfFile:pathToImage options:options error:&error];
    if (self.textureInfo == nil) 
    {
        NSLog(@"Error loading file: %@", [error localizedDescription]);
        return;
    }

    
    self.contentSize = CGSizeMake(self.textureInfo.width, self.textureInfo.height);
    
    TexturedQuad newQuad;
    newQuad.bottomLeftCorner.geometryVertex = CGPointMake(0, 0);
    newQuad.bottomRightCorner.geometryVertex = CGPointMake(self.textureInfo.width, 0);
    newQuad.topLeftCorner.geometryVertex = CGPointMake(0, self.textureInfo.height);
    newQuad.topRightCorner.geometryVertex = CGPointMake(self.textureInfo.width, self.textureInfo.height);

    newQuad.bottomLeftCorner.textureVertex = CGPointMake(0, 0);
    newQuad.bottomRightCorner.textureVertex = CGPointMake(1, 0);
    newQuad.topLeftCorner.textureVertex = CGPointMake(0, 1);
    newQuad.topRightCorner.textureVertex = CGPointMake(1, 1);
    self.quad = newQuad;
}

- (GLKMatrix4) modelMatrix 
{
    GLKMatrix4 modelMatrix = GLKMatrix4Identity;    
    modelMatrix = GLKMatrix4Translate(modelMatrix, self.position.x, self.position.y, self.position.z);
    //modelMatrix = GLKMatrix4Translate(modelMatrix, -self.contentSize.width/2, -self.contentSize.height/2, 0);
    
    return modelMatrix;
}

#pragma mark - render
- (void)render 
{ 
    if ([self.nextPositions count] > 0)
    {
        NSValue *data = [self.nextPositions objectAtIndex:0];
        GLKVector3 newPosition;
        [data getValue:&newPosition];
        self.position = newPosition;
        
        [self.nextPositions removeObjectAtIndex:0];
    }
    
    if (!self.effect)
        NSLog(@"Sprite.m => render => NO effect set!!!");
    
    self.effect.texture2d0.name = self.textureInfo.name;
    self.effect.texture2d0.enabled = YES;
    
    self.effect.transform.modelviewMatrix = self.modelMatrix;
    
    [self.effect prepareToDraw];
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    
    long offset = (long)&_quad;        
    glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, sizeof(TexturedVertex), (void *) (offset + offsetof(TexturedVertex, geometryVertex)));
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(TexturedVertex), (void *) (offset + offsetof(TexturedVertex, textureVertex)));
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

#pragma mark - glideToPosition
- (void)glideToPosition:(GLKVector3)position withinDurationInMilliSecs:(int)durationInMilliSecs
{
    // yes, it's an integer-cast
    int number_of_frames = FRAMES_PER_SECOND / 1000.0f * durationInMilliSecs;
    
    
    if (self.nextPositions == nil)
        self.nextPositions = [[NSMutableArray alloc]initWithCapacity:number_of_frames];
    
    ////////////////////////////////////////////////////////////////////
    // TODO: dirty...change asap !!!
    
    GLKVector3 lastPosition = self.position;
    
    for (int i=1; i<number_of_frames; i++)
    {
        float xStep = round((position.x - lastPosition.x) / (float)(number_of_frames+1-i));
        float yStep = round((position.y - lastPosition.y) / (float)(number_of_frames+1-i));
        
        GLKVector3 newPosition = GLKVector3Make(lastPosition.x + xStep, lastPosition.y + yStep, lastPosition.z);
        NSData *data = [NSValue valueWithBytes:&newPosition objCType:@encode(GLKVector3)];
        [self.nextPositions addObject:data];
        
        lastPosition = newPosition;
    }
    [self.nextPositions addObject:[NSValue valueWithBytes:&position objCType:@encode(GLKVector3)]];   // ensure, that final position is defined position
    // TODO: really...CHANGE IT!!!!!
    ////////////////////////////////////////////////////////////////////
}

#pragma mark - description
- (NSString*)description
{
    NSMutableString *ret = [[NSMutableString alloc] init];
    
    [ret appendFormat:@"Sprite (0x%x):\n", self];
    [ret appendFormat:@"\t\t\tName: %@\n", self.name];
    [ret appendFormat:@"\t\t\tPosition: [%f, %f, %f] (x, y, z)\n", self.position.x, self.position.y, self.position.z];
    [ret appendFormat:@"\t\t\tContent size: [%f, %f] (x, y)\n", self.contentSize.width, self.contentSize.height];
    [ret appendFormat:@"\t\t\tCostume index: %d\n", self.indexOfCurrentCostumeInArray];
    
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


- (CGRect)boundingBox {
    CGRect rect = CGRectMake(self.position.x, self.position.y, self.contentSize.width, self.contentSize.height);
    return rect;
}

- (void)addStartScript:(Script*)script
{
    NSMutableArray *startScripts = [NSMutableArray arrayWithArray:self.startScriptsArray];
    [startScripts addObject:script];
    self.startScriptsArray = [NSArray arrayWithArray:startScripts];    
}

- (void)addWhenScript:(Script*)script
{
    NSMutableArray *whenScripts = [NSMutableArray arrayWithArray:self.whenScriptsArray];
    [whenScripts addObject:script];
    self.whenScriptsArray = [NSArray arrayWithArray:whenScripts];    
}

#pragma mark - script methods
- (void)start
{
    for (Script *script in self.startScriptsArray)
    {
        // ------------------------------------------ THREAD --------------------------------------
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [script execute];
        });
        // ------------------------------------------ END -----------------------------------------
    }
}


- (void)touch:(InputType)type
{
    //todo: throw exception if its not a when script
    for (WhenScript *script in self.whenScriptsArray)
    {
        if (type == script.action)
        {
            // ------------------------------------------ THREAD --------------------------------------
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [script execute];
            });
            // ------------------------------------------ END -----------------------------------------
        }
    }
}




@end
