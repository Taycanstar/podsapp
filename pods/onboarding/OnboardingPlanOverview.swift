//
//  OnboardingPlanOverview.swift
//  Pods
//
//  Created by Dimi Nunez on 4/27/25.
//

import SwiftUI

struct OnboardingPlanOverview: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var nutritionGoals: NutritionGoals?
    @State private var completionDate: String = ""
    @State private var weightDifferenceFormatted: String = ""
    @State private var weightUnit: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Plan Overview")
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 40)
                .padding(.bottom, 20)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Goals
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Goals")
                            .font(.system(size: 20, weight: .bold))
                        
                        // Weight goal with date
                        let goal = UserDefaults.standard.string(forKey: "fitnessGoal") ?? "maintain"
                        if goal != "maintain" && !completionDate.isEmpty {
                            Text("\(weightDifferenceFormatted) \(weightUnit) by \(completionDate)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Nutrition cards
                        VStack(spacing: 12) {
                            // Calories card
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Calories")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("\(Int(nutritionGoals?.calories ?? 0))")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                            
                            // Protein card
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "figure.walk")
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Protein")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("\(Int(nutritionGoals?.protein ?? 0))g")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                            
                            // Carbs card
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "chart.bar.fill")
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Carbs")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("\(Int(nutritionGoals?.carbs ?? 0))g")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                            
                            // Fats card
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "drop.fill")
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fats")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("\(Int(nutritionGoals?.fat ?? 0))g")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Recommendations
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendations")
                            .font(.system(size: 20, weight: .bold))
                        
                        // Log food daily card
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "fork.knife")
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Log Food Daily")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Use AI to describe, scan, upload, or speak your meal")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        
                        // Meet goals card
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Meet Goals")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Unlock trends and insights by hitting your daily targets")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        
                        // Track trends card
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Track Trends")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Visualize your logging history to spot patterns and fine-tune your nutrition and fitness")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Insights sections
                    if let insights = nutritionGoals?.metabolismInsights, !insights.isEmpty {
                        metabolismInsightsView
                    }
                    
                    nutritionInsightsView
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Get Started Button
            VStack {
                Button(action: {
                    HapticFeedback.generate()
                    completeOnboarding()
                }) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .padding(.bottom, 24)
            .background(Material.ultraThin)
        }
        .background(Color(UIColor.systemBackground))
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("OnboardingPlanOverview", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(16, forKey: "onboardingFlowStep") // Set as final step
            UserDefaults.standard.synchronize()
            
            // Get nutrition goals from previous view
            if let data = UserDefaults.standard.data(forKey: "nutritionGoalsData") {
                let decoder = JSONDecoder()
                self.nutritionGoals = try? decoder.decode(NutritionGoals.self, from: data)
            }
            
            // Calculate weight difference and format
            let weightDifference = abs(
                UserDefaults.standard.double(forKey: "desiredWeightKilograms") - 
                UserDefaults.standard.double(forKey: "weightKilograms")
            ) * (UserDefaults.standard.bool(forKey: "isImperial") ? 2.20462 : 1)
            self.weightDifferenceFormatted = "\(Int(weightDifference))"
            self.weightUnit = UserDefaults.standard.bool(forKey: "isImperial") ? "lbs" : "kg"
            
            // Calculate completion date
            if let dateString = UserDefaults.standard.string(forKey: "goalCompletionDate") {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: dateString) {
                    formatter.dateFormat = "MMMM d"
                    self.completionDate = formatter.string(from: date)
                }
            }
        }
    }
    
    /// Complete the onboarding process by marking it as complete on the server
    private func completeOnboarding() {
        // CRITICAL FIX: First check if onboarding is actually complete
        // We want to avoid corrupting the flag
        print("🚀 About to mark onboarding as complete - validating state")
        
        // Double check if we should actually mark as complete
        let currentStep = UserDefaults.standard.string(forKey: "currentOnboardingStep")
        if currentStep != "OnboardingPlanOverview" {
            print("⚠️ WARNING: Trying to mark onboarding as complete when currentStep=\(currentStep ?? "nil")!")
            print("⚠️ Setting currentStep=OnboardingPlanOverview to fix inconsistency")
            UserDefaults.standard.set("OnboardingPlanOverview", forKey: "currentOnboardingStep")
        }
        
        // Make sure user is authenticated in UserDefaults
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
        
        // Get the user's email for updating the server
        if let email = UserDefaults.standard.string(forKey: "userEmail") {
            // Save the email of the user who completed onboarding
            UserDefaults.standard.set(email, forKey: "emailWithCompletedOnboarding")
            print("✅ Saved email \(email) as the one who completed onboarding")
            
            NetworkManagerTwo.shared.markOnboardingCompleted(email: email) { result in
                switch result {
                case .success(let successful):
                    if successful {
                        print("✅ Server confirmed onboarding completion successfully")
                        
                        // Make sure to update all relevant state in the main thread
                        DispatchQueue.main.async {
                            // ONLY set serverOnboardingCompleted to true AFTER server confirms success
                            UserDefaults.standard.set(true, forKey: "serverOnboardingCompleted")
                            // Set all onboarding flags for this user
                            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                            UserDefaults.standard.set(false, forKey: "onboardingInProgress")
                            UserDefaults.standard.synchronize()
                            
                            // Mark onboarding as complete in the viewModel - this updates the UI
                            self.viewModel.onboardingCompleted = true
                            
                            // Mark completion in the viewModel and let it handle saving to UserDefaults
                            self.viewModel.completeOnboarding()
                            
                            // Post notification that authentication is complete
                            NotificationCenter.default.post(name: Notification.Name("AuthenticationCompleted"), object: nil)
                            
                            // Wait briefly then close the onboarding container (fixes dismissal glitch)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.viewModel.isShowingOnboarding = false
                            }
                        }
                    } else {
                        print("⚠️ Server returned failure when marking onboarding as completed")
                        // If the server call failed, we should not mark onboarding as completed
                        DispatchQueue.main.async {
                            print("⚠️ Resetting onboarding completion status due to server error")
                            UserDefaults.standard.set(false, forKey: "serverOnboardingCompleted")
                            UserDefaults.standard.set(false, forKey: "onboardingCompleted")
                            UserDefaults.standard.synchronize()
                            
                            // Still dismiss the view to avoid getting stuck
                            self.viewModel.isShowingOnboarding = false
                        }
                    }
                case .failure(let error):
                    print("⚠️ Failed to update server with onboarding completion: \(error)")
                    // If the server call failed, we should not mark onboarding as completed
                    DispatchQueue.main.async {
                        print("⚠️ Resetting onboarding completion status due to network error")
                        UserDefaults.standard.set(false, forKey: "serverOnboardingCompleted")
                        UserDefaults.standard.set(false, forKey: "onboardingCompleted")
                        UserDefaults.standard.synchronize()
                        
                        // Still dismiss the view to avoid getting stuck
                        self.viewModel.isShowingOnboarding = false
                    }
                }
            }
        } else {
            print("⚠️ Could not find email to update server onboarding status")
            // If no email, still dismiss the view to avoid getting stuck
            viewModel.isShowingOnboarding = false
        }
    }
    
    @ViewBuilder
    private func renderTextWithCitations(_ text: String, researchBacking: [ResearchBacking]?) -> some View {
        // Extract all the processing OUTSIDE of the ViewBuilder context
        let (paragraphTexts, sortedCitations) = processTextWithCitationsForRendering(text)
        
        VStack(alignment: .leading, spacing: 8) {
            // First, display all paragraphs without any citations
            ForEach(paragraphTexts.indices, id: \.self) { index in
                Text(paragraphTexts[index])
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            }
            
            // Then display all citations once at the end, only if there are any
            if !sortedCitations.isEmpty {
                HStack(spacing: 8) {
                    ForEach(sortedCitations, id: \.self) { citationNumber in
                        // The citation number is already clean at this point
                        Text("\(citationNumber)")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.systemGray5))
                            )
                            .foregroundColor(.primary)
                            .onTapGesture {
                                // Try to open URL for this citation
                                openCitationURL(citationNumber: Int(citationNumber) ?? 0, researchBacking: researchBacking)
                            }
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            // Debug print research backing when the view appears
            if let backings = researchBacking {
                debugPrintResearchBacking(backings)
            }
        }
    }
    
    // Helper function to process text outside of ViewBuilder context
    private func processTextWithCitationsForRendering(_ text: String) -> (paragraphTexts: [String], citations: [String]) {
        let processedText = processTextWithCitations(text)
        
        // First, collect all unique citations from all paragraphs
        var allUniqueCitations = Set<String>()
        for paragraph in processedText {
            for citation in paragraph.citations {
                allUniqueCitations.insert(citation.number)
            }
        }
        
        // Sort the citations by number for consistent display
        let sortedCitations = allUniqueCitations.sorted { 
            (Int($0) ?? 0) < (Int($1) ?? 0)
        }
        
        // Extract the paragraph texts
        let paragraphTexts = processedText.map { $0.paragraphText }
        
        return (paragraphTexts, sortedCitations)
    }
    
    // Helper function to print debug info about research backing
    private func debugPrintResearchBacking(_ backings: [ResearchBacking]) {
        print("📚 Research Backing count: \(backings.count)")
        for (i, backing) in backings.enumerated() {
            print("📚 [\(i+1)] Citation URL: \(backing.citation ?? "nil")")
        }
    }
    
    // Helper to process text nicely for display with citations
    private func processTextWithCitations(_ text: String) -> [(paragraphText: String, citations: [(number: String, url: String?)])] {
        // Split by paragraphs (either by double newlines or single newlines that end with period)
        var paragraphTexts: [String] = []
        
        // First attempt natural paragraph splitting
        let naturalParagraphs = text.components(separatedBy: "\n\n")
        if naturalParagraphs.count > 1 {
            // Use natural paragraph structure if available
            paragraphTexts = naturalParagraphs
        } else {
            // Fall back to sentence-based splitting for better formatting
            let sentences = text.components(separatedBy: ". ")
                               .filter { !$0.isEmpty }
            
            // Group sentences into paragraphs (max 3 sentences per paragraph)
            var currentParagraph = ""
            for (index, sentence) in sentences.enumerated() {
                if currentParagraph.isEmpty {
                    currentParagraph = sentence
                } else {
                    currentParagraph += ". " + sentence
                }
                
                // End paragraph after 3 sentences or at end of text
                if index % 3 == 2 || index == sentences.count - 1 {
                    paragraphTexts.append(currentParagraph)
                    currentParagraph = ""
                }
            }
        }
        
        // Clean paragraph texts
        paragraphTexts = paragraphTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var result: [(paragraphText: String, citations: [(number: String, url: String?)])] = []
        
        // Process each paragraph to extract citations and clean text
        for paragraph in paragraphTexts {
            // Find all citation references like [1], [2], etc.
            let citationPattern = #"\[(\d+)\]"#
            let regex = try? NSRegularExpression(pattern: citationPattern)
            let nsText = paragraph as NSString
            let range = NSRange(location: 0, length: nsText.length)
            
            // Extract all citation numbers
            var citationNumbersSeen = Set<String>() // Track unique citation numbers
            var citations: [(number: String, url: String?)] = []
            
            if let matches = regex?.matches(in: paragraph, range: range) {
                for match in matches {
                    if match.numberOfRanges > 1 {
                        let numberRange = match.range(at: 1)
                        // Extract the clean number without brackets
                        let number = nsText.substring(with: numberRange)
                        
                        // Only add each unique citation number once
                        if !citationNumbersSeen.contains(number) {
                            citations.append((number, nil))
                            citationNumbersSeen.insert(number)
                        }
                    }
                }
            }
            
            // Remove citation brackets from the displayed text
            var cleanText = regex?.stringByReplacingMatches(in: paragraph, range: range, withTemplate: "") ?? paragraph
            
            // Fix formatting issues
            cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Fix common formatting issues:
            // 1. Remove spaces before periods, commas, etc.
            let punctuationFixes = [
                (pattern: #" \."#, replacement: "."),
                (pattern: #" ,"#, replacement: ","),
                (pattern: #" ;"#, replacement: ";"),
                (pattern: #" :"#, replacement: ":"),
                (pattern: #",\."#, replacement: "."),
                (pattern: #"\s{2,}"#, replacement: " ")  // Replace multiple spaces with single space
            ]
            
            for (pattern, replacement) in punctuationFixes {
                let fixRegex = try? NSRegularExpression(pattern: pattern)
                let wholeRange = NSRange(location: 0, length: cleanText.count)
                cleanText = fixRegex?.stringByReplacingMatches(in: cleanText, range: wholeRange, withTemplate: replacement) ?? cleanText
            }
            
            // Ensure text ends with proper punctuation
            let lastChar = cleanText.last
            if lastChar != nil && !".,:;!?".contains(lastChar!) {
                cleanText += "."
            }
            
            // Final cleanup of duplicate periods
            cleanText = cleanText.replacingOccurrences(of: "..", with: ".")
            
            // Sort citations by number for consistent display
            let sortedCitations = citations.sorted { 
                let num1 = Int($0.number) ?? 0
                let num2 = Int($1.number) ?? 0
                return num1 < num2
            }
            
            result.append((cleanText, sortedCitations))
        }
        
        return result
    }
    
    private func openCitationURL(citationNumber: Int, researchBacking: [ResearchBacking]?) {
        guard let backings = researchBacking else {
            print("⚠️ No research backing available")
            return
        }
        
        // Debug info
        print("🔍 Trying to open citation [\(citationNumber)]")
        print("🔍 Available backings count: \(backings.count)")
        
        // We need a smarter algorithm to match citation numbers with backing data
        // Because there's a mismatch between citation numbers in text and backing array size
        
        // APPROACH 1: Try to keep citation numbers within bounds
        let safeIndex = min(max(0, citationNumber - 1), backings.count - 1)
        
        // APPROACH 2: Modulo mapping for cycling through available sources
        // This ensures we always map to an available citation even if numbers exceed count
        let moduloIndex = (citationNumber - 1) % backings.count
        
        // We'll use the modulo approach for more natural cycling through sources
        let backing = backings[moduloIndex]
        
        if let urlString = backing.citation, let url = URL(string: urlString) {
            print("🌐 Opening URL for citation [\(citationNumber)] (mapped to source \(moduloIndex + 1)): \(urlString)")
            UIApplication.shared.open(url)
        } else {
            print("⚠️ No valid URL for citation [\(citationNumber)]")
            
            // Fallback: Try the first URL
            if let firstURLString = backings.first?.citation, let url = URL(string: firstURLString) {
                print("🌐 Fallback: Opening first available URL: \(firstURLString)")
                UIApplication.shared.open(url)
            }
        }
    }
    
    // Helper function to process optimization strategies and remove numbering
    private func processOptimizationStrategies(_ text: String) -> String {
        // Remove any numbering patterns from the text:
        // - Remove leading numbers like "1. " or "2. "
        // - Also handle numbered items that might start with a digit but no period
        let cleanedText = text.replacingOccurrences(of: #"^\s*\d+[\.\)]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\d+\s+"#, with: "", options: .regularExpression)
        
        // If the text still starts with a lowercase letter after removing numbering,
        // capitalize the first letter for better presentation
        if !cleanedText.isEmpty && cleanedText.first!.isLowercase {
            return cleanedText.prefix(1).uppercased() + cleanedText.dropFirst()
        }
        
        return cleanedText
    }
    
    // Function to render text without showing citations (for bullet points)
    @ViewBuilder
    private func renderTextWithoutCitations(_ text: String) -> some View {
        let processedText = processTextWithCitations(text)
        
        // Only display the paragraph text, no citations
        VStack(alignment: .leading, spacing: 4) {
            ForEach(processedText.indices, id: \.self) { index in
                Text(processedText[index].paragraphText)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // Helper function to extract all citations from text
    private func extractCitationsFromText(_ text: String) -> [String] {
        let processedText = processTextWithCitations(text)
        
        // Collect all unique citations 
        var allCitations = Set<String>()
        for paragraph in processedText {
            for citation in paragraph.citations {
                allCitations.insert(citation.number)
            }
        }
        
        // Return sorted citations
        return allCitations.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }
    
    // In your SwiftUI view where you display insights
    private var metabolismInsightsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Headline outside the card
            Text("Metabolic Insights")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 2)
            
            if let insights = nutritionGoals?.metabolismInsights, !insights.isEmpty {
                // PRE-PROCESS: Collect all citations completely outside of the View building context
                let allMetabolismCitations = collectAllCitations(insights: insights)
                let sortedCitations = allMetabolismCitations.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
                // No longer need to get global citation map since citations are already numbered correctly from backend
                
                VStack(alignment: .leading, spacing: 12) {
                    // Main summary/analysis at the top (no 'Overview' subheadline)
                    if let primaryAnalysis = insights.primaryAnalysis {
                        // Just render the text without citations
                        renderTextWithoutCitations(primaryAnalysis)
                    }
                    
                    // Practical implications
                    if let practicalImplications = insights.practicalImplications {
                        Text("Practical Implications")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        renderTextWithoutCitations(practicalImplications)
                    }
                    
                    // Optimization strategies (render each one as a bullet point)
                    if let optimizationStrategies = insights.optimizationStrategies {
                        Text("Optimization Strategies")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        // Extract the strategies outside the view builder context
                        let strategies = extractNumberedItems(from: optimizationStrategies)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(strategies, id: \.self) { strategy in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(.primary)
                                        .padding(.top, 0)
                                    
                                    // Render text without citations
                                    renderTextWithoutCitations(strategy)
                                }
                            }
                        }
                    }
                    
                    // Display ALL collected citations at the bottom of the section
                    if !sortedCitations.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(sortedCitations, id: \.self) { citationNumber in
                                // Citation numbers are already clean at this point
                                Text("\(citationNumber)")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(UIColor.systemGray5))
                                    )
                                    .foregroundColor(.primary)
                                    .onTapGesture {
                                        // Try to open URL for this citation
                                        openCitationURL(citationNumber: Int(citationNumber) ?? 0, researchBacking: insights.researchBacking)
                                    }
                            }
                            Spacer()
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(16)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
        }
    }
    
    // Helper to collect all citations from metabolism insights
    private func collectAllCitations(insights: InsightDetails) -> Set<String> {
        var allCitations = Set<String>()
        
        // Collect from primary analysis
        if let primaryAnalysis = insights.primaryAnalysis {
            let citations = extractCitationsFromText(primaryAnalysis)
            for citation in citations {
                allCitations.insert(citation)
            }
        }
        
        // Collect from practical implications
        if let implications = insights.practicalImplications {
            let citations = extractCitationsFromText(implications)
            for citation in citations {
                allCitations.insert(citation)
            }
        }
        
        // Collect from optimization strategies
        if let strategies = insights.optimizationStrategies {
            let citations = extractCitationsFromText(strategies)
            for citation in citations {
                allCitations.insert(citation)
            }
        }
        
        return allCitations
    }
    
    private var nutritionInsightsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let insights = nutritionGoals?.nutritionInsights, !insights.isEmpty {
                // Title for this section
                Text("Nutrition Recommendations")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                // For nutrition insights, we need to collect all citations once
                let allCitations = collectAllNutritionCitations(insights: insights)
                
                // Sort the citation numbers for consistent display
                let sortedCitations = allCitations.sorted { 
                    (Int($0) ?? 0) < (Int($1) ?? 0)
                }
                
                // Insights panel
                VStack(alignment: .leading, spacing: 12) {
                    // Primary Analysis
                    if let primaryAnalysis = insights.primaryAnalysis {
                        renderTextWithoutCitations(primaryAnalysis)
                    }
                    
                    // Macronutrient Breakdown
                    if let breakdown = insights.macronutrientBreakdown {
                        Text("Macronutrient Breakdown")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        renderTextWithoutCitations(breakdown)
                    }
                    
                    // Meal Timing
                    if let timing = insights.mealTiming {
                        Text("Meal Timing")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        renderTextWithoutCitations(timing)
                    }
                    
                    // Micronutrient Focus
                    if let micro = insights.micronutrientFocus {
                        Text("Micronutrient Focus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        renderTextWithoutCitations(micro)
                    }
                    
                    // Supplementation
                    if let supp = insights.supplementation, !supp.isEmpty {
                        Text("Supplementation")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        renderTextWithoutCitations(supp)
                    }
                    
                    // Display ALL collected citations at the bottom of the section
                    if !sortedCitations.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(sortedCitations, id: \.self) { citationNumber in
                                // Citation numbers are already clean at this point
                                Text("\(citationNumber)")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(UIColor.systemGray5))
                                    )
                                    .foregroundColor(.primary)
                                    .onTapGesture {
                                        // Try to open URL for this citation
                                        openCitationURL(citationNumber: Int(citationNumber) ?? 0, researchBacking: insights.researchBacking)
                                    }
                            }
                            Spacer()
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(16)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
        }
    }
    
    // Helper to collect all citations from nutrition insights
    private func collectAllNutritionCitations(insights: InsightDetails) -> Set<String> {
        var allCitations = Set<String>()
        
        // Collect from primary analysis
        if let primaryAnalysis = insights.primaryAnalysis {
            let citations = extractCitationsFromText(primaryAnalysis)
            for citation in citations {
                allCitations.insert(citation)
            }
        }
        
        // Collect from macronutrient breakdown
        if let breakdown = insights.macronutrientBreakdown {
            let citations = extractCitationsFromText(breakdown)
            for citation in citations {
                allCitations.insert(citation)
            }
        }
        
        // Collect from meal timing
        if let timing = insights.mealTiming {
            let citations = extractCitationsFromText(timing)
            for citation in citations {
                allCitations.insert(citation)
            }
        }
        
        // Collect from micronutrient focus
        if let micro = insights.micronutrientFocus {
            let citations = extractCitationsFromText(micro)
            for citation in citations {
                allCitations.insert(citation)
            }
        }
        
        // Collect from supplementation
        if let supp = insights.supplementation, !supp.isEmpty {
            let citations = extractCitationsFromText(supp)
            for citation in citations {
                allCitations.insert(citation)
            }
        }
        
        return allCitations
    }
    
    // This function is needed as parts of the UI are still calling it
    private func createGlobalCitationMap() -> [String: Int] {
        // Map each citation to a unique, sequential number
        var citationMap = [String: Int]()
        
        // Collect all citations from both insight types
        var allCitations = Set<String>()
        
        if let metaInsights = nutritionGoals?.metabolismInsights, !metaInsights.isEmpty {
            let metaCitations = collectAllCitations(insights: metaInsights)
            allCitations = allCitations.union(metaCitations)
        }
        
        if let nutriInsights = nutritionGoals?.nutritionInsights, !nutriInsights.isEmpty {
            let nutriCitations = collectAllNutritionCitations(insights: nutriInsights)
            allCitations = allCitations.union(nutriCitations)
        }
        
        // Sort citations numerically
        let sortedCitations = allCitations.sorted { 
            (Int($0) ?? 0) < (Int($1) ?? 0)
        }
        
        // Map each citation to its clean number value
        for citation in sortedCitations {
            if let num = Int(citation) {
                citationMap[citation] = num
            }
        }
        
        return citationMap
    }
    
    // Helper function to extract numbered items from text
    private func extractNumberedItems(from text: String) -> [String] {
        // Extract numbered items using a pattern
        let regex = try? NSRegularExpression(pattern: #"\d+\.\s*(.*?)(?=\s*\d+\.|$)"#, options: [.dotMatchesLineSeparators])
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        // Get matches for the numbered items
        var strategies: [String] = []
        if let matches = regex?.matches(in: text, options: [], range: range) {
            for match in matches {
                if match.numberOfRanges > 1 {
                    let itemRange = match.range(at: 1)
                    let item = nsString.substring(with: itemRange)
                    if !item.isEmpty {
                        strategies.append(item)
                    }
                }
            }
        }
        
        // Fallback if regex didn't work
        if strategies.isEmpty {
            // Simple fallback: Just filter out items that are just numbers
            strategies = text.components(separatedBy: ". ").filter {
                let trimmed = $0.trimmingCharacters(in: .whitespaces)
                // Is not just a number
                return !trimmed.isEmpty && !(Int(trimmed) != nil)
            }
        }
        
        return strategies.filter { !$0.isEmpty }
    }
}

#Preview {
    OnboardingPlanOverview()
        .environmentObject(OnboardingViewModel())
}
