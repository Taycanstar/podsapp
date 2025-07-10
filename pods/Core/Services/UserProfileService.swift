//
//  UserProfileService.swift
//  pods
//
//  Created by Dimi Nunez on 7/10/25.
//

// FILE: Services/UserProfileService.swift
import Foundation
import SwiftData

class UserProfileService {
    static let shared = UserProfileService()
    
    private init() {}
    
    // Get or create user profile
    func getUserProfile(for userEmail: String, context: ModelContext) -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { profile in
                profile.email == userEmail
            }
        )
        
        do {
            let profiles = try context.fetch(descriptor)
            if let existingProfile = profiles.first {
                return existingProfile
            } else {
                // Create new profile with defaults
                let newProfile = UserProfile(
                    email: userEmail,
                    fitnessGoal: .strength,
                    experienceLevel: .beginner
                )
                context.insert(newProfile)
                
                do {
                    try context.save()
                    print("✅ Created new user profile for: \(userEmail)")
                } catch {
                    print("❌ Error saving new user profile: \(error)")
                }
                
                return newProfile
            }
        } catch {
            print("❌ Error fetching user profile: \(error)")
            // Create new profile as fallback
            let newProfile = UserProfile(
                email: userEmail,
                fitnessGoal: .strength,
                experienceLevel: .beginner
            )
            context.insert(newProfile)
            return newProfile
        }
    }
    
    // Update user profile
    func updateUserProfile(email: String, fitnessGoal: FitnessGoal, experienceLevel: ExperienceLevel, context: ModelContext) {
        let profile = getUserProfile(for: email, context: context)
        profile.fitnessGoal = fitnessGoal
        profile.experienceLevel = experienceLevel
        profile.updatedAt = Date()
        
        do {
            try context.save()
            print("✅ Updated user profile for: \(email)")
        } catch {
            print("❌ Error updating user profile: \(error)")
        }
    }
} 