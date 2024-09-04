//
//  SubscriptionView.swift
//  Podstack
//
//  Created by Dimi Nunez on 9/2/24.
//

import SwiftUI

struct SubscriptionView: View {
    @State private var selectedTab = 0
    @State private var showPricingSheet = false
    @StateObject private var subscriptionManager = SubscriptionManager()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.isTabBarVisible) var isTabBarVisible
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("dkBg").edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    ScrollView {
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
                                
                                Text(SubscriptionTier.allCases[selectedTab].name)
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
                                SubscriptionTierView(tier: .plus)
                                    .tag(0)
                                SubscriptionTierView(tier: .team)
                                    .tag(1)
                            }
                            .padding(.top, 15)
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .frame(height: geometry.size.height * 0.6)

                            
                            PageIndicator(currentPage: selectedTab, pageCount: 2)
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showPricingSheet = true
                    }) {
                        Text("Starting at \(subscriptionManager.startingPrice(for: SubscriptionTier.allCases[selectedTab]))")
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
            }
        }
        .onAppear {
            isTabBarVisible.wrappedValue = false
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
        .sheet(isPresented: $showPricingSheet) {
            PricingView(tier: SubscriptionTier.allCases[selectedTab], subscriptionManager: subscriptionManager)
        }
    }
}
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
                        savings: "SAVE 13%",
                        billingInfo: subscriptionManager.annualBillingInfo(for: tier)
                    )
                    
                    PricingOptionView(
                        title: "Monthly plan",
                        price: subscriptionManager.monthlyPrice(for: tier),
                        billingInfo: subscriptionManager.monthlyBillingInfo(for: tier)
                    )
                }
                .padding()
                
                Button(action: {
                    subscriptionManager.purchase(tier: tier)
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
        }
    }
}

struct PricingOptionView: View {
    let title: String
    let price: String
    var savings: String? = nil
    let billingInfo: String
    
    var body: some View {
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
//        .background(Color(.systemGray6))
//        .cornerRadius(10)
        .background(Color("mdBg"))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}



