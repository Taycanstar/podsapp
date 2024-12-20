import SwiftUI

struct InfoView: View {
    @State private var username: String = ""
    @State private var name: String = ""
    @State private var birthday: Date? = nil
    @State private var showingDatePicker = false
    @State private var showError: Bool = false // State to control error message visibility
    @State private var errorMessage: String = ""
    @State private var isLoading = false
    
    // DateFormatter to display the date
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    @EnvironmentObject var viewModel: OnboardingViewModel
    var networkManager: NetworkManager = NetworkManager()
    @Environment(\.presentationMode) var presentationMode // For dismissing the view
    
    var body: some View {
        VStack {
            HStack {
                Button("Sign out") {
//                    presentationMode.wrappedValue.dismiss()
                    viewModel.currentStep = .landing
                }
                .foregroundColor(Color(red: 35/255, green: 108/255, blue: 255/255))
                .padding()
                Spacer()
            }

           

            VStack(alignment: .leading, spacing: 20) {
                Text("Finish creating your Humuli account")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Text("Tell us about you.")
                    .font(.headline)
                    .foregroundColor(.gray)

                ZStack(alignment: .leading) {
                    CustomTextField(placeholder: "Name", text: $name)
                        .autocapitalization(.none)
                        .keyboardType(.default)
                }
                
                ZStack(alignment: .leading) {
                    CustomTextField(placeholder: "Username", text: $username)
                        .autocapitalization(.none)
                        .keyboardType(.default)
                }
                Button(action: {
                               self.showingDatePicker = true
                           }) {
                               HStack {
                                   Text(birthday == nil ? "Birthday" : dateFormatter.string(from: birthday!)) // Use the birthday date if selected, otherwise show placeholder
                                       .foregroundColor(birthday == nil ? Color(red: 0.75, green: 0.75, blue: 0.75) : .black)
                                       .font(.system(size: 16))

                                   Spacer()
                                   Image(systemName: "calendar")
                                       .foregroundColor(.gray)
                               }
                               .padding() // This adds padding inside the button
                                             .background(Color.white) // Background color of the button
                                             .cornerRadius(10) // Rounded corners for the button
                                             .overlay(
                                                 RoundedRectangle(cornerRadius: 10)
                                                     .stroke(Color.gray, lineWidth: 0.2) // Custom border for the button
                                             )
                                         
                           }
                           .buttonStyle(PlainButtonStyle())
                           .sheet(isPresented: $showingDatePicker) {
                               // Temporary variable for holding the date selection during picking
                               var tempBirthday = self.birthday ?? Date() // Start with the current birthday or today's date

                               VStack {
                                   DatePicker(
                                       "Select your birthday",
                                       selection: Binding<Date>(
                                           get: { tempBirthday }, // Use temporary date for picker interaction
                                           set: { newDate in
                                               tempBirthday = newDate // Update temporary date with picker's selection
                                           }
                                       ),
                                       in: ...Date(),
                                       displayedComponents: [.date]
                                   )
                                   .datePickerStyle(WheelDatePickerStyle())
                                   .labelsHidden()

                                   Button("Done") {
                                       self.birthday = tempBirthday // Apply the temporary date to the actual birthday state
                                       self.showingDatePicker = false // Dismiss the date picker sheet
                                   }
                                   .foregroundColor(Color(red: 35/255, green: 108/255, blue: 255/255))
                                   .padding()
                               }
                           }
                if showError {
                          Text(errorMessage)
                              .foregroundColor(.red)
                              .padding()
                      }

            }
            
            .padding(.horizontal)
            
            Spacer()
            
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

                Button(action: {

                                 guard !name.isEmpty, !username.isEmpty, let birthdayDate = birthday else {
                                     self.errorMessage = "Name, and birthday are required."
                                     self.showError = true
                                     return
                                 }
                                 
                                 // Proceed with formatting the birthday and calling network manager function
                                
                    
                    let isoDateFormatter = ISO8601DateFormatter()
                    isoDateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate] // Ensure YYYY-MM-DD format
                    let formattedBirthday = isoDateFormatter.string(from: birthdayDate)

                                 
                                 // Example function call, replace with actual implementation
                    networkManager.updateUserInformation(email: viewModel.email, name: name, username: username, birthday: formattedBirthday) { success, message in
                                     DispatchQueue.main.async {
                                         isLoading = true
                                         if success {
                                             // Handle success
                                             self.viewModel.username = self.username
                                             
                                viewModel.currentStep = .welcome
                                             isLoading = false
                                         } else {
                                             // Handle error, optionally update errorMessage and showError to inform the user
                                             print("Error updating user information: \(message)")
                                         }
                                     }
                                 }
                                 
                                 // Reset error state when button action is successfully triggered
                                 self.showError = false
               
                }) {
                        Text("Continue")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 35/255, green: 108/255, blue: 255/255))
                            .cornerRadius(10)
                
                }
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .padding(.bottom, 50)
            .background(Color.white)
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.white)
//        .preferredColorScheme(.light)
    }
    
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView()
    }
}





struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding() // This adds padding around the text
//            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(10) // Rounded corners for the background
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 0.2) // Custom border
            )
    }
}
