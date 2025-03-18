import SwiftUI

enum Tab {
    case home
    case pods
    case meals
    case recipes
    case profile
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var recipeManager: RecipeManager
    @EnvironmentObject var podManager: PodManager
    @EnvironmentObject var activityManager: ActivityManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(Tab.home)
            
            PodsView()
                .tabItem {
                    Label("Pods", systemImage: "square.grid.2x2")
                }
                .tag(Tab.pods)
            
            MealsView()
                .tabItem {
                    Label("Meals", systemImage: "fork.knife")
                }
                .tag(Tab.meals)
            
            RecipesView()
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }
                .tag(Tab.recipes)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(Tab.profile)
        }
        .task {
            // Perform any initializations or data loading for the tab view
            if let email = userManager.userEmail {
                foodManager.initialize(userEmail: email)
                recipeManager.initialize(userEmail: email)
                podManager.initialize(userEmail: email)
                activityManager.initialize(userEmail: email, podManager: podManager)
            }
        }
    }
} 