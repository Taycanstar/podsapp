import SwiftUI

struct InfoView: View {
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var birthday: Date? = nil
    @State private var showingDatePicker = false
    
    // DateFormatter to display the date
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    

    @Environment(\.presentationMode) var presentationMode // For dismissing the view
    
    var body: some View {
        VStack {
            HStack {
                Button("Sign out") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(Color(red: 70/255, green: 87/255, blue: 245/255))
                .padding()
                Spacer()
            }

           

            VStack(alignment: .leading, spacing: 20) {
                Text("Finish creating your Humuli account")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Tell us about you.")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                TextField("First name", text: $firstName)
                    .textFieldStyle(CustomTextFieldStyle())
                   

                TextField("Last name", text: $lastName)
                    .textFieldStyle(CustomTextFieldStyle())
                
//                TextField("Birthday", text: $birthday)
//                    .textFieldStyle(CustomTextFieldStyle())
                
                Button(action: {
                               self.showingDatePicker = true
                           }) {
                               HStack {
                                   Text(birthday == nil ? "Birthday" : dateFormatter.string(from: birthday!)) // Use the birthday date if selected, otherwise show placeholder
                                       .foregroundColor(birthday == nil ? Color(red: 0.75, green: 0.75, blue: 0.75) : .primary)
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
                                   .padding()
                               }
                           }

            }
            .padding(.horizontal)
            
            Spacer()
            
            VStack {
                Text("By clicking \"Continue\", you agree to our Terms and acknowledge our Privacy Policy.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()

                Button(action: {
                    // Handle continue action here
                }) {
                    Text("Continue")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 70/255, green: 87/255, blue: 245/255))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 50)
        }
        .navigationBarBackButtonHidden(true)
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
            .background(Color.white) // Background color of the TextField
            .cornerRadius(10) // Rounded corners for the background
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 0.2) // Custom border
            )
    }
}

