//
//  PodItemCell.swift
//  pods
//
//  Created by Dimi Nunez on 4/1/24.
//

import SwiftUI
import AVKit

struct PodItemCell: View {
     var item: PodItem
    var player: AVPlayer
    
    init(item: PodItem, player: AVPlayer) {
        self.item = item
        self.player = player
    }
    
    var body: some View {
        ZStack {
            CustomVideoPlayer(player: player)
                .containerRelativeFrame([.horizontal, .vertical])
            
            VStack{
                Spacer()
                
                HStack(alignment: .bottom){
                    VStack(alignment: .leading) {
                        Text("Lewis Hamilton")
                            .fontWeight(.semibold)
                        Text("Still we raise")
                        
                    }
                    .foregroundStyle(.white)
                    .font(.subheadline)
                    
                    Spacer()
                    
                    VStack(spacing: 28){
                        Circle()
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.gray)
                        Button{
                            
                        } label:{
                            VStack{
                                Image(systemName: "heart.fill")
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(.white)
                                Text("27")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                           
                            
                        }
                        
                        Button{
                            
                        } label:{
                            VStack{
                                Image(systemName: "ellipsis.bubble.fill")
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(.white)
                                Text("27")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                           
                        }
                        
                        Button{
                            
                        } label:{
                            VStack{
                                Image(systemName: "bookmark.fill")
                                    .resizable()
                                    .frame(width: 22, height: 28)
                                    .foregroundStyle(.white)
                                Text("27")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                           
                        }
                        
                        Button{
                            
                        } label:{
                            VStack{
                                Image(systemName: "arrowshape.turn.up.right.fill")
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(.white)
                                
                                Text("27")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                            
                        }
                        
                    }
                    
                    
                }
                .padding(.bottom,80)
                
            }
            .padding()
        }
        .onTapGesture {
            switch player.timeControlStatus {
            case .paused:
                player.play()
            case .waitingToPlayAtSpecifiedRate:
                break
            case .playing:
                player.pause()
            @unknown default:
                break
            }
        }
    }
}

//#Preview {
//    PodItemCell(item:2)
//}