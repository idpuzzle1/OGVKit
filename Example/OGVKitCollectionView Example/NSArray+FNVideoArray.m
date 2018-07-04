//
//  NSArray+FNVideoArray.m
//  OGVKit Example
//
//  Created by a_uhankin on 04.07.2018.
//  Copyright © 2018 Brion Vibber. All rights reserved.
//

#import "NSArray+FNVideoArray.h"
#import "OGVCommonsExampleItem.h"
#import "OGVLinkedExampleItem.h"

@implementation NSArray (FNVideoArray)

+ (NSArray<OGVExampleItem *> *)videoArray {
    return @[
             // Wikipedia stuff
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Wikipedia VisualEditor"
                                                 filename:@"Sneak Preview - Wikipedia VisualEditor.webm"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"¿Qué es Wikipedia?"
                                                 filename:@"¿Qué es Wikipedia?.ogv"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Wikipedia Edit 2015"
                                                 filename:@"Wikipedia Edit 2015.webm"],
             
             // Third-party stuff
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Open Access: Empowering Discovery"
                                                 filename:@"How_Open_Access_Empowered_a_16-Year-Old_to_Make_Cancer_Breakthrough.ogv"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Curiosity's Seven Minutes of Terror"
                                                 filename:@"Curiosity's Seven Minutes of Terror.ogv"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Alaskan Huskies (heavy motion)"
                                                 filename:@"Alaskan_Huskies_-_Sled_Dogs_-_Ivalo_2013.ogv"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"International Space Station"
                                                 filename:@"Ultra High Definition Video from the International Space Station (Reel 1).webm"],
             
             // Blender open movies
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Tears of Steel (sci-fi)"
                                                 filename:@"Tears_of_Steel_1080p.webm"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Sintel (animation)"
                                                 filename:@"Sintel_movie_4K.webm"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Caminandes - Llama Drama (animation)"
                                                 filename:@"Caminandes- Llama Drama - Short Movie.ogv"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Caminandes - Gran Dillama (animation)"
                                                 filename:@"Caminandes - Gran Dillama - Blender Foundation's new Open Movie.webm"],
             
             // High frame rate
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Big Buck Bunny (60fps animation)"
                                                 filename:@"Big_Buck_Bunny_4K.webm"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Wiki Makes Video (60fps)"
                                                 filename:@"Wiki Makes Video Intro 4 26.webm"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"London apartment (60fps game engine)"
                                                 filename:@"UE4Arch.com - London apartment.webm"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Job Simulator (60fps game engine)"
                                                 filename:@"Spectator Mode for Job Simulator - a new way to display social VR footage.webm"],
             
             // Video-only tests
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Myopa (video only)"
                                                 filename:@"Myopa_-_2015-05-02.webm"],
             
             // Audio-only tests
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Bach C Major (audio)"
                                                 filename:@"Bach_C_Major_Prelude_Werckmeister.ogg"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"Arigato (short audio)"
                                                 filename:@"Ja-arigato.oga"],
             [[OGVCommonsExampleItem alloc] initWithTitle:@"O du froehliche (Opus audio)"
                                                 filename:@"O du froehliche - GL 238 audio.opus"],
             
             // Local test files
             [[OGVLinkedExampleItem alloc] initWithTitle:@"Res switching (local)"
                                                     URL:[[NSBundle mainBundle] URLForResource:@"vp8-res-switch"
                                                                                 withExtension:@"webm"]],
             
             [[OGVLinkedExampleItem alloc] initWithTitle:@"Bunny low-res intro (local)"
                                                     URL:[[NSBundle mainBundle] URLForResource:@"bunny"
                                                                                 withExtension:@"ogv"]],
             
             [[OGVLinkedExampleItem alloc] initWithTitle:@"Bunny low-res VP9 Vorbis (local)"
                                                     URL:[[NSBundle mainBundle] URLForResource:@"bunny"
                                                                                 withExtension:@"webm"]],
             
             [[OGVLinkedExampleItem alloc] initWithTitle:@"Bunny low-res VP9 OPUS (local)"
                                                     URL:[[NSBundle mainBundle] URLForResource:@"bunny_opus_vp9"
                                                                                 withExtension:@"webm"]],
             
             [[OGVLinkedExampleItem alloc] initWithTitle:@"Bunny low-res VP8 OPUS (local)"
                                                     URL:[[NSBundle mainBundle] URLForResource:@"bunny_opus_vp8"
                                                                                 withExtension:@"webm"]],
             
             
             [[OGVLinkedExampleItem alloc] initWithTitle:@"Kitty cat MP4 (local)"
                                                     URL:[[NSBundle mainBundle] URLForResource:@"kitty-short"
                                                                                 withExtension:@"mp4"]],
             
             [[OGVLinkedExampleItem alloc] initWithTitle:@"Hacking 4:2:0 (local)"
                                                     URL:[[NSBundle mainBundle] URLForResource:@"hacking-420"
                                                                                 withExtension:@"ogv"]],
             
             [[OGVLinkedExampleItem alloc] initWithTitle:@"Hacking 4:2:2 (local)"
                                                     URL:[[NSBundle mainBundle] URLForResource:@"hacking-422"
                                                                                 withExtension:@"ogv"]],
             
             [[OGVLinkedExampleItem alloc] initWithTitle:@"Hacking 4:4:4 (local)"
                                                     URL:[[NSBundle mainBundle] URLForResource:@"hacking-444"
                                                                                 withExtension:@"ogv"]]];
}

@end
