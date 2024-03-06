import SwiftUI

struct EmailVerificationView: View {
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
                
                Text("An email to {email} has been sent. Click on the link to get started.")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text("Resend email")
                    .font(.headline)
                    .foregroundColor(Color(red: 70/255, green: 87/255, blue: 245/255))
                
              
            

            }
            .padding(.horizontal)
            
            Spacer()
            
            VStack {
                

                Button(action: {
                    // Handle continue action here
                }) {
                    Text("I have verified my email")
                        .foregroundColor(.black)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 50)
        }
        .navigationBarBackButtonHidden(true)
    }
    
}

struct EmailVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        EmailVerificationView()
    }
}




