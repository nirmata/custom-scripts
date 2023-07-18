import csv

# Read the user_details_devops.csv file and store username-email mapping in a dictionary
user_details = {}
with open('user_details_devops.csv', 'r') as file:
    reader = csv.DictReader(file)
    for row in reader:
        user_details[row['Username']] = row['Email']

# Read the output.csv file and create a list of dictionaries with the desired columns
output_data = []
with open('output.csv', 'r') as file:
    reader = csv.DictReader(file)
    for row in reader:
        username_column = 'Username'  # Replace with the actual column name in the output.csv file
        environment_column = 'Environment Name'  # Replace with the actual column name
        permission_column = 'Environment Permission'  # Replace with the actual column name

        username = row[username_column]
        email = user_details.get(username, '')  # Get the email from the user_details dictionary
        output_row = {
            'Email': email,
            'Username': username,
            'Environment Name': row[environment_column],
            'Environment Permission': row[permission_column]
        }
        output_data.append(output_row)

# Write the output_data to the new CSV file
fieldnames = ['Email', 'Username', 'Environment Name', 'Environment Permission']
with open('output_combined.csv', 'w', newline='') as file:
    writer = csv.DictWriter(file, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(output_data)
