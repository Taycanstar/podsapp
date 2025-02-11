
import SwiftUI
import Foundation
import StoreKit



struct SubscriptionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @Environment(\.colorScheme) var colorScheme
//    @StateObject private var subscriptionManager = SubscriptionManager()
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    let displayedTiers: [SubscriptionTier] = [.plusMonthly]
    
    @State private var isLoading = true
 
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("dkBg").edgesIgnoringSafeArea(.all)
                
                if isLoading {
                                  ProgressView("Loading subscription info...")
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            if subscriptionManager.hasActiveSubscription() {
                            ActiveSubscriptionView(viewModel: _viewModel)
                            } else {
                                NoSubscriptionView(geometry: geometry)
                            }

                        }
                        .padding()
                    }
                }
                

            }
        }
        .onAppear {
                 isTabBarVisible.wrappedValue = false
                 subscriptionManager.setOnboardingViewModel(viewModel)
            testDateParsing()
                 Task {
                     await fetchSubscriptionInfo()
                 }
             }
    
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionUpdated)) { _ in
            Task {
                await fetchSubscriptionInfo()
            }
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
    
    func testDateParsing() {
        let dateString = "2024-11-17T05:26:20.494385+00:00"
        if let date = ISO8601DateFormatter.fullFormatter.date(from: dateString) {
            print("Successfully parsed date: \(date)")
            let currentDate = Date()
            print("Current date: \(currentDate)")
            print("Is future date: \(date > currentDate)")
        } else {
            print("Failed to parse date")
        }
    }
    func fetchSubscriptionInfo() async {
        isLoading = true
        await subscriptionManager.fetchSubscriptionInfo(for: viewModel.email)
        isLoading = false
    }
}

struct ActiveSubscriptionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showCancelAlert = false
    @State private var showUpgradeSheet = false
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var isManagingSubscriptions = false
    @State private var showRenewAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Image("copy") // Replace with your app icon
                .resizable()
                .scaledToFit()
                .frame(height: 50)
            
            Text(subscriptionManager.subscriptionInfo?.plan ?? "Unknown Plan")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "creditcard")

                    Text(getCurrentSubscriptionPrice())
                }
                HStack {
                    Image(systemName: "calendar")
                    Text(getSubscriptionStatusText())
                }
            }
            .padding(.bottom, 15)
//            if let subscriptionInfo = subscriptionManager.subscriptionInfo {
//                           if subscriptionInfo.plan?.contains("Plus") == true {
//                               upgradeButton(text: "Upgrade to Podstack Team")
//                           } else if subscriptionInfo.plan?.contains("Team") == true {
//                               upgradeButton(text: "Upgrade and add another team")
//                           }
//                       }
            
//            if viewModel.subscriptionPlan?.contains("Plus") == true {
//                Button(action: {
//                    showUpgradeSheet = true
//                }) {
//                    Text("Upgrade to Podstack Team")
//                        .font(.system(size: 16))
//                        .fontWeight(.semibold)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.blue)
//                        .cornerRadius(10)
//                }
//            } else if viewModel.subscriptionPlan?.contains("Team") == true {
//                Button(action: {
//                    showUpgradeSheet = true
//                }) {
//                    Text("Upgrade and add another team")
//                        .font(.system(size: 16))
//                        .fontWeight(.semibold)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.accentColor)
//                        .cornerRadius(10)
//                }
//            }
            if subscriptionManager.shouldShowRenewButton() {
                   Button(action: {
                       showRenewAlert = true
                   }) {
                       Text("Renew Subscription")
                           .font(.system(size: 16))
                           .fontWeight(.regular)
                           .foregroundColor(.blue)
                           .frame(maxWidth: .infinity)
                           .padding()
                           .background(Color.blue.opacity(0.1))
                           .cornerRadius(10)
                   }
                   .alert(isPresented: $showRenewAlert) {
                       Alert(
                           title: Text("Renew Subscription"),
                           message: Text("Are you sure you want to renew your subscription?"),
                           primaryButton: .default(Text("Renew")) {
                               renewSubscription()
                           },
                           secondaryButton: .cancel()
                       )
                   }
               } else if !subscriptionManager.isSubscriptionCancelled() {
                   Button(action: {
                       showCancelAlert = true
                   }) {
                       Text("Cancel Subscription")
                           .font(.system(size: 16))
                           .fontWeight(.regular)
                           .foregroundColor(.red)
                           .frame(maxWidth: .infinity)
                           .padding()
                           .background(Color.red.opacity(0.1))
                           .cornerRadius(10)
                   }
                   .alert(isPresented: $showCancelAlert) {
                       Alert(
                           title: Text("Cancel Subscription"),
                           message: Text("Are you sure you want to cancel your subscription? You can still access your subscription until \(formatSubscriptionDate(subscriptionManager.subscriptionInfo?.expiresAt ?? ""))"),
                           primaryButton: .destructive(Text("Cancel Subscription")) {
                               cancelSubscription()
                           },
                           secondaryButton: .cancel()
                       )
                   }
               }

            VStack {
                HStack {
                    Text("By continuing, you agree to the ")
                    
                    Text("Terms")
                        .foregroundColor(Color.accentColor)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "http://humuli.com/policies/terms") {
                                UIApplication.shared.open(url)
                            }
                        }
                    
                    Text(" and ")
                    
                    Text("Privacy Policy")
                        .foregroundColor(Color.accentColor)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "https://humuli.com/policies/privacy-policy") {
                                UIApplication.shared.open(url)
                            }
                        }
                }
                .font(.footnote)
                .foregroundColor(.gray)
            }
        }


        .padding()
        .background(Color("mdBg"))
        .cornerRadius(15)
        .sheet(isPresented: $showUpgradeSheet) {
                   PricingView(tier: .teamMonthly, subscriptionManager: subscriptionManager)
               }

    }
    
    private func upgradeButton(text: String) -> some View {
            Button(action: {
                showUpgradeSheet = true
            }) {
                Text(text)
                    .font(.system(size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
        }
        
    private func getCurrentSubscriptionPrice() -> String {
           if let plan = subscriptionManager.subscriptionInfo?.plan {
               if plan.contains("Plus") {
                   return subscriptionManager.monthlyPrice(for: .plusMonthly)
               } else if plan.contains("Team") {
                   return subscriptionManager.monthlyPrice(for: .teamMonthly)
               }
           }
           return "Unknown"
       }

    private func getSubscriptionStatusText() -> String {
           guard let subscriptionInfo = subscriptionManager.subscriptionInfo,
                 let expiresAtString = subscriptionInfo.expiresAt,
                 let expiresAt = ISO8601DateFormatter.fullFormatter.date(from: expiresAtString) else {
               return "Status unknown"
           }

           let formattedDate = DateFormatter.subscriptionDateFormatter.string(from: expiresAt)
           
           if subscriptionInfo.status == "active" {
               return subscriptionInfo.renews ? "Renews on \(formattedDate)" : "Expires on \(formattedDate)"
           } else if subscriptionInfo.status == "cancelled" {
               return "Active until \(formattedDate)"
           } else {
               return "Status unknown"
           }
       }

    private func renewSubscription() {
        Task {
            do {
                try await subscriptionManager.renewSubscription(userEmail: viewModel.email)
                print("Subscription renewed successfully")
                // Optionally, you can show a success message or update the UI
            } catch {
                print("Error renewing subscription: \(error)")
                
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

    private func cancelSubscription() {

           Task {
               do {
                   try await subscriptionManager.cancelSubscription(userEmail: viewModel.email)

                   print("Subscription cancelled")
                   // Optionally, you can show a success message or navigate to a different view
               } catch {
                   print("error cancelling subscription: \(error)")
               }
           }
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

    @State private var showPricingSheet = false
    let displayedTier: SubscriptionTier = .plusMonthly
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    var body: some View {
        VStack(spacing: 10) {
            // Title card
            Text(displayedTier.name)
                .font(.headline)
                .fontWeight(.bold)
                .padding()
                .background(Color("mdBg"))
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.top, 10)
            
            // Subscription tier view
            SubscriptionTierView(tier: .plusMonthly)
                .padding(.top, 15)
                .frame(height: geometry.size.height * 0.6)

            Button(action: {
                showPricingSheet = true
            }) {
                Text("Starting at \(subscriptionManager.startingPrice(for: displayedTier))")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            
            Spacer()
            
            // Terms and Privacy Policy
            VStack {
                HStack {
                    Text("By continuing, you agree to the ")
                    Text("Terms")
                        .foregroundColor(Color.accentColor)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "http://humuli.com/policies/terms") {
                                UIApplication.shared.open(url)
                            }
                        }
                    Text(" and ")
                    Text("Privacy Policy")
                        .foregroundColor(Color.accentColor)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "https://humuli.com/policies/privacy-policy") {
                                UIApplication.shared.open(url)
                            }
                        }
                }
                .font(.footnote)
                .foregroundColor(.gray)
            }
        }
        .sheet(isPresented: $showPricingSheet) {
            PricingView(tier: displayedTier, subscriptionManager: SubscriptionManager())
        }
    }
}

//struct NoSubscriptionView: View {
//    let geometry: GeometryProxy
//    @EnvironmentObject var viewModel: OnboardingViewModel
//
//    @State private var selectedTab = 0
//    @State private var showPricingSheet = false
//    let displayedTiers: [SubscriptionTier] = [.plusMonthly, .teamMonthly]
//    @StateObject private var subscriptionManager = SubscriptionManager()
//
//    var body: some View {
//        VStack(spacing: 10) {
//            // Title card with arrows
//            HStack {
//                Button(action: {
//                    withAnimation {
//                        selectedTab = max(0, selectedTab - 1)
//                    }
//                }) {
//                    Image(systemName: "chevron.left")
//                        .foregroundColor(.accentColor)
//                }
//                .opacity(selectedTab > 0 ? 1 : 0.3)
//
//                Spacer()
//
//                Text(displayedTiers[selectedTab].name)
//                    .font(.headline)
//                    .fontWeight(.bold)
//
//                Spacer()
//
//                Button(action: {
//                    withAnimation {
//                        selectedTab = min(1, selectedTab + 1)
//                    }
//                }) {
//                    Image(systemName: "chevron.right")
//                        .foregroundColor(.accentColor)
//                }
//                .opacity(selectedTab < 1 ? 1 : 0.3)
//            }
//            .padding()
//            .background(Color("mdBg"))
//            .cornerRadius(15)
//            .overlay(
//                RoundedRectangle(cornerRadius: 15)
//                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
//            )
//            .padding(.horizontal)
//            .padding(.top, 10)
//
//            // TabView with subscription tiers
//            TabView(selection: $selectedTab) {
//                SubscriptionTierView(tier: .plusMonthly)
//                    .tag(0)
//                SubscriptionTierView(tier: .teamMonthly)
//                    .tag(1)
//            }
//            .padding(.top, 15)
//            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
//            .frame(height: geometry.size.height * 0.6)
//
//            PageIndicator(currentPage: selectedTab, pageCount: 2)
//                .padding()
//
//            Button(action: {
//                showPricingSheet = true
//            }) {
//                Text("Starting at \(subscriptionManager.startingPrice(for: displayedTiers[selectedTab]))")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.accentColor)
//                    .cornerRadius(10)
//            }
//            .padding(.horizontal)
//            .padding(.bottom, 20)
//
//            Spacer()
//            VStack {
//                HStack {
//                    Text("By continuing, you agree to the ")
//
//                    Text("Terms")
//                        .foregroundColor(Color.accentColor)
//                        .underline()
//                        .onTapGesture {
//                            if let url = URL(string: "http://humuli.com/policies/terms") {
//                                UIApplication.shared.open(url)
//                            }
//                        }
//
//                    Text(" and ")
//
//                    Text("Privacy Policy")
//                        .foregroundColor(Color.accentColor)
//                        .underline()
//                        .onTapGesture {
//                            if let url = URL(string: "https://humuli.com/policies/privacy-policy") {
//                                UIApplication.shared.open(url)
//                            }
//                        }
//                }
//                .font(.footnote)
//                .foregroundColor(.gray)
//            }
//        }
//        .sheet(isPresented: $showPricingSheet) {
//            PricingView(tier: displayedTiers[selectedTab], subscriptionManager: SubscriptionManager())
//        }
//    }
//}

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
                                              userEmail: viewModel.email, onboardingViewModel: viewModel
                                          )
                                          await subscriptionManager.fetchSubscriptionInfo(for: viewModel.email)
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
                
           
                
                VStack {
                    HStack {
                        Text("By subscribing, you agree to our  ")
                        
                        Text("Terms")
                            .foregroundColor(Color.accentColor)
                            .underline()
                            .onTapGesture {
                                if let url = URL(string: "http://humuli.com/policies/terms") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        
                        Text(" and ")
                        
                        Text("Privacy Policy")
                            .foregroundColor(Color.accentColor)
                            .underline()
                            .onTapGesture {
                                if let url = URL(string: "https://humuli.com/policies/privacy-policy") {
                                    UIApplication.shared.open(url)
                                }
                            }
                    
                    }
                    .font(.footnote)
                    .foregroundColor(.gray)
                }



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


