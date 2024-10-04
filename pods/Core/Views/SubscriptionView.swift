//
//  SubscriptionView.swift
//  Podstack
//
//  Created by Dimi Nunez on 9/2/24.
//

import SwiftUI
import Foundation
import StoreKit



struct SubscriptionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @Environment(\.colorScheme) var colorScheme
    
    let displayedTiers: [SubscriptionTier] = [.plusMonthly, .teamMonthly]
 
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("dkBg").edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.hasActiveSubscription() {
                            ActiveSubscriptionView(viewModel: _viewModel)
                        } else {
                            NoSubscriptionView(geometry: geometry)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            isTabBarVisible.wrappedValue = false
//            viewModel.checkSubscriptionStatus()
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .font(.system(size: 20))
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Subscription")
                    .font(.headline)
            }
        }
    }
}

struct ActiveSubscriptionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showCancelAlert = false
    @State private var showUpgradeSheet = false
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var isManagingSubscriptions = false

    var body: some View {
        VStack(spacing: 20) {
            Image("copy") // Replace with your app icon
                .resizable()
                .scaledToFit()
                .frame(height: 50)
            
            Text(viewModel.subscriptionPlan ?? "Unknown Plan")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "creditcard")
//                    Text(viewModel.subscriptionCost)
                    Text(getCurrentSubscriptionPrice())
                }
                HStack {
                    Image(systemName: "calendar")
                    Text(getSubscriptionStatusText())
                }
            }
            .padding(.bottom, 15)
            
            
            if viewModel.subscriptionPlan?.contains("Plus") == true {
                Button(action: {
                    showUpgradeSheet = true
                }) {
                    Text("Upgrade to Podstack Team")
                        .font(.system(size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            } else if viewModel.subscriptionPlan?.contains("Team") == true {
                Button(action: {
                    showUpgradeSheet = true
                }) {
                    Text("Upgrade and add another team")
                        .font(.system(size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
            }
            
//            Button(action: {
//                showCancelAlert = true
//            }) {
//                Text("Cancel Subscription")
//                    .font(.system(size: 16))
//                    .fontWeight(.regular)
//                    .foregroundColor(.red)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.red.opacity(0.1))
//                    .cornerRadius(10)
//            }
//            .alert(isPresented: $showCancelAlert) {
//                Alert(
//                    title: Text("Cancel Subscription"),
//                    message: Text("Are you sure you want to cancel your subscription? You can still access your subscription until \(formatSubscriptionDate(viewModel.subscriptionExpiresAt ?? "at the end of the billing period"))."),
//                    primaryButton: .destructive(Text("Cancel Subscription")) {
////                        viewModel.cancelSubscription()
//                        print("tapped cancel")
//                    },
//                    secondaryButton: .cancel()
//                )
//            }
            Button(action: {
                isManagingSubscriptions = true
                          openManageSubscriptions()
                      }) {
                          Text("Manage Subscription")
                              .font(.system(size: 16))
                              .fontWeight(.regular)
                              .foregroundColor(.blue)
                              .frame(maxWidth: .infinity)
                              .padding()
                              .background(Color.blue.opacity(0.1))
                              .cornerRadius(10)
                      }
            
            Text(getSubscriptionInfoText())
                           .font(.caption)
                           .foregroundColor(.secondary)
                           .multilineTextAlignment(.center)
                           .padding()
                       
//            
//            Button(action: {
//                // Handle About Subscriptions and Privacy
//            }) {
//                Text("About Subscriptions and Privacy")
//                    .font(.footnote)
//                    .foregroundColor(.blue)
//            }
        }
        .padding()
        .background(Color("mdBg"))
        .cornerRadius(15)
        .sheet(isPresented: $showUpgradeSheet) {
                   PricingView(tier: .teamMonthly, subscriptionManager: subscriptionManager)
               }
        .onChange(of: isManagingSubscriptions) { newValue in
                 if !newValue {
                     // User has returned from subscription management
                     Task {
                         await subscriptionManager.checkAndUpdateSubscriptionStatus()
//                         await viewModel.refreshSubscriptionInfo()
                     }
                 }
             }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                   if isManagingSubscriptions {
                       isManagingSubscriptions = false
                   }
               }
    }
    
    private func openManageSubscriptions() {
         if #available(iOS 15.0, *) {
             if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                 Task {
                     try? await AppStore.showManageSubscriptions(in: scene)
                 }
             }
         } else {
             // Fallback for iOS versions before 15.0
             if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                 UIApplication.shared.open(url, options: [:], completionHandler: nil)
             }
         }
     }
    private func getSubscriptionInfoText() -> String {
            if viewModel.subscriptionStatus == "active" {
                if viewModel.subscriptionRenews {
                    return "Your subscription will automatically renew on \(formatSubscriptionDate(viewModel.subscriptionExpiresAt ?? ""))."
                } else {
                    return getCancellationMessage()
                }
            } else {
                return "Your subscription has expired. Renew now to regain access to all features."
            }
        }
    
    private func getCurrentSubscriptionPrice() -> String {
          let subscriptionManager = SubscriptionManager()
          if let plan = viewModel.subscriptionPlan {
              if plan.contains("Plus") {
                  return subscriptionManager.monthlyPrice(for: .plusMonthly)
              } else if plan.contains("Team") {
                  return subscriptionManager.monthlyPrice(for: .teamMonthly)
              }
          }
          return "Unknown"
      }
      
      private func getSubscriptionStatusText() -> String {
          guard let dateString = viewModel.subscriptionExpiresAt else {
              return "Unknown"
          }
          let formattedDate = formatSubscriptionDate(dateString)
          return viewModel.subscriptionRenews ? "Renews \(formattedDate)" : "Expires \(formattedDate)"
      }
    
    
      
      private func getCancellationMessage() -> String {
          guard let dateString = viewModel.subscriptionExpiresAt else {
              return "You can still access your subscription until the end of the billing period."
          }
          let formattedDate = formatSubscriptionDate(dateString)
          return "You can still access your subscription until \(formattedDate)."
      }
}

struct NoSubscriptionView: View {
    let geometry: GeometryProxy
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var selectedTab = 0
    @State private var showPricingSheet = false
    let displayedTiers: [SubscriptionTier] = [.plusMonthly, .teamMonthly]
    
    var body: some View {
        VStack(spacing: 10) {
            // Title card with arrows
            HStack {
                Button(action: {
                    withAnimation {
                        selectedTab = max(0, selectedTab - 1)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.accentColor)
                }
                .opacity(selectedTab > 0 ? 1 : 0.3)
                
                Spacer()
                
                Text(displayedTiers[selectedTab].name)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        selectedTab = min(1, selectedTab + 1)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.accentColor)
                }
                .opacity(selectedTab < 1 ? 1 : 0.3)
            }
            .padding()
            .background(Color("mdBg"))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.top, 10)
            
            // TabView with subscription tiers
            TabView(selection: $selectedTab) {
                SubscriptionTierView(tier: .plusMonthly)
                    .tag(0)
                SubscriptionTierView(tier: .teamMonthly)
                    .tag(1)
            }
            .padding(.top, 15)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: geometry.size.height * 0.6)

            PageIndicator(currentPage: selectedTab, pageCount: 2)
                .padding()
            
            Button(action: {
                showPricingSheet = true
            }) {
                Text("Starting at \(SubscriptionManager().startingPrice(for: displayedTiers[selectedTab]))")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showPricingSheet) {
            PricingView(tier: displayedTiers[selectedTab], subscriptionManager: SubscriptionManager())
        }
    }
}

// Existing SubscriptionTierView, PageIndicator, and PricingView remain unchanged

struct SubscriptionTierView: View {
    let tier: SubscriptionTier
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(tier.features, id: \.self) { feature in
                HStack {
                    Text(feature)
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color("mxdBg"))
        .cornerRadius(15)
//        .shadow(radius: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0.5)
        )
        .padding(.horizontal, 20)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 44, 44, 44) : Color(rgb: 230, 230, 230)
    }
}

struct PageIndicator: View {
    let currentPage: Int
    let pageCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { page in
                Circle()
                    .fill(page == currentPage ? Color.blue : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
            }
        }
    }
}


struct PricingView: View {
    let tier: SubscriptionTier
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPlan: PlanType = .annual
    @State private var showError = false
    @State private var errorMessage = ""
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    enum PlanType {
        case annual, monthly
    }
    
    var savingsPercentage: Int {
        switch tier {
        case .plusMonthly, .plusYearly:
            return 33
        case .teamMonthly, .teamYearly:
            return 22
        case .none:
            return 0
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(tier.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(spacing: 15) {
                    PricingOptionView(
                        title: "Annual plan",
                        price: subscriptionManager.annualPrice(for: tier),
                        savings: "SAVE \(savingsPercentage)%",
                        billingInfo: subscriptionManager.annualBillingInfo(for: tier),
                        isSelected: selectedPlan == .annual,
                        action: { selectedPlan = .annual }
                    )
                    
                    PricingOptionView(
                        title: "Monthly plan",
                        price: subscriptionManager.monthlyPrice(for: tier),
                        billingInfo: subscriptionManager.monthlyBillingInfo(for: tier),
                        isSelected: selectedPlan == .monthly,
                        action: { selectedPlan = .monthly }
                    )
                }
                .padding()
                
                Button(action: {
                    Task {
                               do {
                                   try await subscriptionManager.purchase(
                                       tier: tier,
                                       planType: selectedPlan,
                                       userEmail: viewModel.email,
                                       onboardingViewModel: viewModel
                                   )
                                   presentationMode.wrappedValue.dismiss()
                               } catch {
                                   errorMessage = error.localizedDescription
                                   showError = true
                               }
                           }
                }) {
                    Text("Subscribe & Pay")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding()
                
                Text("By subscribing, you agree to our Purchaser Terms of Service. Subscriptions auto-renew until canceled, as described in the Terms. Cancel anytime. Cancel at least 24 hours prior to renewal to avoid additional charges.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .navigationBarTitle("Choose a Plan", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showError) {
                Alert(title: Text("Purchase Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
}

struct PricingOptionView: View {
    let title: String
    let price: String
    var savings: String? = nil
    let billingInfo: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.headline)
                    if let savings = savings {
                        Text(savings)
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .padding(.horizontal, 5)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(5)
                    }
                    Spacer()
                    Text(price)
                        .font(.headline)
                }
                Text(billingInfo)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color("mdBg"))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension DateFormatter {
    static let subscriptionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()
}

func formatSubscriptionDate(_ dateString: String) -> String {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    if let date = dateFormatter.date(from: dateString) {
        return DateFormatter.subscriptionDateFormatter.string(from: date)
    }
    return "Unknown"
}
