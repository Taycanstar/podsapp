//
//  ExerciseDatabase.swift
//  Pods
//
//  Created by Dimi Nunez on 6/14/25.
//

import Foundation

struct ExerciseDatabase {
    static func getAllExercises() -> [ExerciseData] {
        // First try to load from JSON
        if let exercises = loadFromJSON(), !exercises.isEmpty {
            return exercises
        }
        
        // Fallback to embedded data
        print("📚 Using embedded exercise database")
        return getEmbeddedExercises()
    }
    
    private static func loadFromJSON() -> [ExerciseData]? {
        guard let path = Bundle.main.path(forResource: "exercises", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let exercises = try? JSONDecoder().decode([ExerciseData].self, from: data) else {
            return nil
        }
        
        print("✅ Loaded \(exercises.count) exercises from JSON")
        return exercises
    }
    
    private static func getEmbeddedExercises() -> [ExerciseData] {
        // This is a subset of real exercises from the spreadsheet
        // In a production app, you might want to include all 1200+ exercises here
        return [
            ExerciseData(id: 3, name: "Air bike", exerciseType: "Strength", bodyPart: "Waist", equipment: "Body weight", gender: "Male", target: "Obliques", synergist: "Gluteus Maximus, Quadriceps, Rectus Abdominis"),
            ExerciseData(id: 15, name: "Assisted Parallel Close Grip Pull-up", exerciseType: "Strength", bodyPart: "Back", equipment: "Leverage machine", gender: "Male", target: "Latissimus Dorsi", synergist: "Brachialis, Brachioradialis, Deltoid Posterior, Levator Scapulae, Teres Major, Teres Minor, Trapezius Middle Fibers, Trapezius Upper Fibers"),
            ExerciseData(id: 17, name: "Assisted Pull-up", exerciseType: "Strength", bodyPart: "Back", equipment: "Leverage machine", gender: "Male", target: "Latissimus Dorsi", synergist: "Brachialis, Brachioradialis, Deltoid Posterior, Infraspinatus, Teres Major, Teres Minor, Trapezius Middle Fibers, Trapezius Upper Fibers"),
            ExerciseData(id: 25, name: "Barbell Bench Press", exerciseType: "Strength", bodyPart: "Chest", equipment: "Barbell", gender: "Male", target: "Pectoralis Major Sternal Head", synergist: "Deltoid Anterior, Pectoralis Major Clavicular Head, Triceps Brachii"),
            ExerciseData(id: 28, name: "Barbell Clean and Press", exerciseType: "Strength", bodyPart: "Shoulders", equipment: "Barbell", gender: "Male", target: "Deltoid Anterior, Gluteus Maximus, Quadriceps", synergist: ""),
            ExerciseData(id: 31, name: "Barbell Curl", exerciseType: "Strength", bodyPart: "Upper Arms", equipment: "Barbell", gender: "Male", target: "Biceps Brachii", synergist: "Brachialis, Brachioradialis"),
            ExerciseData(id: 33, name: "Barbell Decline Bench Press", exerciseType: "Strength", bodyPart: "Chest", equipment: "Barbell", gender: "Male", target: "Pectoralis Major Sternal Head", synergist: "Deltoid Anterior, Pectoralis Major Clavicular Head, Triceps Brachii"),
            ExerciseData(id: 41, name: "Barbell Front Raise", exerciseType: "Strength", bodyPart: "Shoulders", equipment: "Barbell", gender: "Male", target: "Deltoid Anterior", synergist: "Deltoid Lateral, Pectoralis Major Clavicular Head, Serratus Anterior"),
            ExerciseData(id: 44, name: "Barbell Good Morning", exerciseType: "Strength", bodyPart: "Thighs", equipment: "Barbell", gender: "Male", target: "Hamstrings", synergist: "Adductor Magnus, Gluteus Maximus"),
            ExerciseData(id: 47, name: "Barbell Incline Bench Press", exerciseType: "Strength", bodyPart: "Chest", equipment: "Barbell", gender: "Male", target: "Pectoralis Major Clavicular Head", synergist: "Deltoid Anterior, Triceps Brachii"),
            ExerciseData(id: 54, name: "Barbell Lunge", exerciseType: "Strength", bodyPart: "Thighs", equipment: "Barbell", gender: "Male", target: "Gluteus Maximus, Quadriceps", synergist: "Adductor Magnus, Soleus"),
            ExerciseData(id: 60, name: "Barbell Overhead Squat", exerciseType: "Strength", bodyPart: "Thighs", equipment: "Barbell", gender: "Male", target: "Gluteus Maximus, Quadriceps", synergist: "Adductor Magnus, Soleus"),
            ExerciseData(id: 68, name: "Barbell Preacher Curl", exerciseType: "Strength", bodyPart: "Upper Arms", equipment: "Barbell", gender: "Male", target: "Biceps Brachii", synergist: "Brachialis"),
            ExerciseData(id: 73, name: "Barbell Pullover", exerciseType: "Strength", bodyPart: "Back", equipment: "Barbell", gender: "Male", target: "Latissimus Dorsi", synergist: "Pectoralis Major Clavicular Head, Pectoralis Major Sternal Head, Teres Major, Triceps Brachii"),
            ExerciseData(id: 75, name: "Barbell Rear Delt Raise", exerciseType: "Strength", bodyPart: "Shoulders", equipment: "Barbell", gender: "Male", target: "Deltoid Posterior", synergist: "Biceps Brachii, Brachialis, Brachioradialis, Deltoid Lateral, Levator Scapulae, Trapezius Upper Fibers, Wrist Flexors"),
            ExerciseData(id: 84, name: "Barbell Rollout", exerciseType: "Strength", bodyPart: "Hips", equipment: "Barbell", gender: "Male", target: "Iliopsoas, Rectus Abdominis", synergist: "Adductor Brevis, Adductor Longus, Deltoid Posterior, Pectineous, Pectoralis Major Sternal Head, Sartorius, Tensor Fasciae Latae, Teres Major"),
            ExerciseData(id: 85, name: "Barbell Romanian Deadlift", exerciseType: "Strength", bodyPart: "Hips", equipment: "Barbell", gender: "Male", target: "Erector Spinae, Gluteus Maximus", synergist: "Adductor Magnus, Hamstrings, Quadriceps, Soleus"),
            ExerciseData(id: 88, name: "Barbell Seated Calf Raise", exerciseType: "Strength", bodyPart: "Calves", equipment: "Barbell", gender: "Male", target: "Gastrocnemius", synergist: "Soleus"),
            ExerciseData(id: 95, name: "Barbell Shrug", exerciseType: "Strength", bodyPart: "Back", equipment: "Barbell", gender: "Male", target: "Trapezius Upper Fibers", synergist: "Levator Scapulae, Trapezius Middle Fibers"),
            ExerciseData(id: 114, name: "Barbell Step-up", exerciseType: "Strength", bodyPart: "Thighs", equipment: "Barbell", gender: "Male", target: "Gluteus Maximus, Quadriceps", synergist: "Adductor Magnus, Soleus"),
            ExerciseData(id: 125, name: "Barbell Wrist Curl (version 2)", exerciseType: "Strength", bodyPart: "Forearms", equipment: "Barbell", gender: "Male", target: "Wrist Flexors", synergist: ""),
            ExerciseData(id: 128, name: "Battling Ropes", exerciseType: "Strength", bodyPart: "Shoulders", equipment: "Rope", gender: "Male", target: "Deltoid Posterior", synergist: "Brachialis, Brachioradialis, Deltoid Lateral, Infraspinatus, Teres Minor, Trapezius Lower Fibers, Trapezius Middle Fibers"),
            
            // Add some popular bodyweight exercises
            ExerciseData(id: 1401, name: "Push-up", exerciseType: "Strength", bodyPart: "Chest", equipment: "Body weight", gender: "Male", target: "Pectoralis Major Sternal Head", synergist: "Deltoid Anterior, Pectoralis Major Clavicular Head, Triceps Brachii"),
            ExerciseData(id: 1402, name: "Bodyweight Squat", exerciseType: "Strength", bodyPart: "Thighs", equipment: "Body weight", gender: "Male", target: "Gluteus Maximus, Quadriceps", synergist: "Adductor Magnus, Soleus"),
            ExerciseData(id: 1403, name: "Pull-up", exerciseType: "Strength", bodyPart: "Back", equipment: "Body weight", gender: "Male", target: "Latissimus Dorsi", synergist: "Biceps Brachii, Brachialis, Brachioradialis, Deltoid Posterior, Infraspinatus, Teres Major, Teres Minor, Trapezius Lower Fibers, Trapezius Middle Fibers"),
            ExerciseData(id: 1404, name: "Plank", exerciseType: "Strength", bodyPart: "Waist", equipment: "Body weight", gender: "Male", target: "Rectus Abdominis", synergist: "Obliques, Transverse Abdominis"),
            ExerciseData(id: 1405, name: "Burpee", exerciseType: "Strength", bodyPart: "Cardio", equipment: "Body weight", gender: "Male", target: "Full Body", synergist: "All major muscle groups"),
            ExerciseData(id: 1406, name: "Mountain Climber", exerciseType: "Strength", bodyPart: "Cardio", equipment: "Body weight", gender: "Male", target: "Rectus Abdominis", synergist: "Deltoid Anterior, Hip Flexors, Quadriceps"),
            ExerciseData(id: 1407, name: "Jumping Jacks", exerciseType: "Cardio", bodyPart: "Cardio", equipment: "Body weight", gender: "Male", target: "Cardiovascular System", synergist: "Calves, Deltoids, Hip Abductors"),
            ExerciseData(id: 1408, name: "Dips", exerciseType: "Strength", bodyPart: "Upper Arms", equipment: "Body weight", gender: "Male", target: "Triceps Brachii", synergist: "Deltoid Anterior, Pectoralis Major Clavicular Head, Pectoralis Major Sternal Head"),
            
            // Add some dumbbell exercises
            ExerciseData(id: 1501, name: "Dumbbell Bench Press", exerciseType: "Strength", bodyPart: "Chest", equipment: "Dumbbell", gender: "Male", target: "Pectoralis Major Sternal Head", synergist: "Deltoid Anterior, Pectoralis Major Clavicular Head, Triceps Brachii"),
            ExerciseData(id: 1502, name: "Dumbbell Row", exerciseType: "Strength", bodyPart: "Back", equipment: "Dumbbell", gender: "Male", target: "Latissimus Dorsi", synergist: "Biceps Brachii, Brachialis, Brachioradialis, Deltoid Posterior, Infraspinatus, Teres Major, Teres Minor, Trapezius Lower Fibers, Trapezius Middle Fibers"),
            ExerciseData(id: 1503, name: "Dumbbell Shoulder Press", exerciseType: "Strength", bodyPart: "Shoulders", equipment: "Dumbbell", gender: "Male", target: "Deltoid Anterior", synergist: "Deltoid Lateral, Triceps Brachii"),
            ExerciseData(id: 1504, name: "Dumbbell Bicep Curl", exerciseType: "Strength", bodyPart: "Upper Arms", equipment: "Dumbbell", gender: "Male", target: "Biceps Brachii", synergist: "Brachialis, Brachioradialis"),
            ExerciseData(id: 1505, name: "Dumbbell Lunges", exerciseType: "Strength", bodyPart: "Thighs", equipment: "Dumbbell", gender: "Male", target: "Gluteus Maximus, Quadriceps", synergist: "Adductor Magnus, Soleus"),
        ]
    }
} 
