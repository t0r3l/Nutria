import json
import numpy as np

# Constants
ACTIVITY_MULTIPLIERS = {
    "very low": 1.2,
    "low": 1.375,
    "moderate": 1.55,
    "high": 1.725,
    "very high": 1.9
}

OBJECTIF_CALORIES = {
    "maintain": 0,
    "weight loss": -250,
    "weight gain": 250
}

def calculate_bmr(event, context):
    """
    Lambda function to calculate Basal Metabolic Rate (BMR)

    Expected event structure:
    {
        "gender": "male" or "female",
        "age": number,
        "height": number (cm),
        "weight_in_kg": number
    }
    """
    try:
        # Extract parameters from event
        gender = event.get('gender')
        age = event.get('age')
        height = event.get('height')
        weight_in_kg = event.get('weight_in_kg')

        # Validate required parameters
        if not all([gender, age, height, weight_in_kg]):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required parameters: gender, age, height, weight_in_kg'})
            }

        # Calculate BMR using Mifflin-St Jeor equation
        if gender == "male":
            bmr = 10 * weight_in_kg + 6.25 * height - 5 * age + 5
        elif gender == "female":
            bmr = 10 * weight_in_kg + 6.25 * height - 5 * age - 161
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Gender must be "male" or "female"'})
            }

        return {
            'statusCode': 200,
            'body': json.dumps({
                'bmr': bmr,
                'gender': gender,
                'age': age,
                'height': height,
                'weight_in_kg': weight_in_kg
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def calculate_tdee(event, context):
    """
    Lambda function to calculate Total Daily Energy Expenditure (TDEE)

    Expected event structure:
    {
        "bmr": number,
        "activity_level": "very low" | "low" | "moderate" | "high" | "very high",
        "objectif": "maintain" | "weight loss" | "weight gain"
    }
    """
    try:
        # Extract parameters from event
        bmr = event.get('bmr')
        activity_level = event.get('activity_level')
        objectif = event.get('objectif')

        # Validate required parameters
        if not all([bmr is not None, activity_level, objectif]):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required parameters: bmr, activity_level, objectif'})
            }

        # Get multipliers
        activity_multiplier = ACTIVITY_MULTIPLIERS.get(activity_level)
        objectif_calories = OBJECTIF_CALORIES.get(objectif)

        if activity_multiplier is None:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Invalid activity_level. Must be one of: {list(ACTIVITY_MULTIPLIERS.keys())}'})
            }

        if objectif_calories is None:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Invalid objectif. Must be one of: {list(OBJECTIF_CALORIES.keys())}'})
            }

        # Calculate TDEE
        tdee = bmr * activity_multiplier + (bmr * activity_multiplier) * (objectif_calories/100)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'tdee': tdee,
                'bmr': bmr,
                'activity_level': activity_level,
                'activity_multiplier': activity_multiplier,
                'objectif': objectif,
                'objectif_calories': objectif_calories
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def calculate_macros(event, context):
    """
    Lambda function to calculate macro targets

    Expected event structure:
    {
        "tdee": number,
        "weight_in_kg": number,
        "body_fat_percent": number (optional, defaults to 0.12)
    }
    """
    try:
        # Extract parameters from event
        tdee = event.get('tdee')
        weight_in_kg = event.get('weight_in_kg')
        body_fat_percent = event.get('body_fat_percent', 0.12)

        # Validate required parameters
        if not all([tdee is not None, weight_in_kg is not None]):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required parameters: tdee, weight_in_kg'})
            }

        # Calculate lean body mass
        lbm_kg = weight_in_kg - (weight_in_kg * body_fat_percent)

        # Calculate macros
        protein_g = lbm_kg * 1.6
        protein_cal = protein_g * 4

        lipid_cal = 0.30 * tdee
        lipid_g = lipid_cal / 9

        glucides_cal = 0.45 * tdee
        glucides_g = glucides_cal / 4

        return {
            'statusCode': 200,
            'body': json.dumps({
                'tdee': tdee,
                'lean_body_mass_kg': lbm_kg,
                'protein_g': protein_g,
                'protein_cal': protein_cal,
                'lipid_g': lipid_g,
                'lipid_cal': lipid_cal,
                'glucides_g': glucides_g,
                'glucides_cal': glucides_cal
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def get_complete_nutrition_profile(event, context):
    """
    Lambda function that combines all calculations to get complete nutrition profile

    Expected event structure:
    {
        "gender": "male" or "female",
        "age": number,
        "height": number (cm),
        "weight_in_kg": number,
        "activity_level": "very low" | "low" | "moderate" | "high" | "very high",
        "objectif": "maintain" | "weight loss" | "weight gain",
        "body_fat_percent": number (optional, defaults to 0.12)
    }
    """
    try:
        # Extract all parameters
        gender = event.get('gender')
        age = event.get('age')
        height = event.get('height')
        weight_in_kg = event.get('weight_in_kg')
        activity_level = event.get('activity_level')
        objectif = event.get('objectif')
        body_fat_percent = event.get('body_fat_percent', 0.12)

        # Validate required parameters
        required_params = ['gender', 'age', 'height', 'weight_in_kg', 'activity_level', 'objectif']
        missing_params = [param for param in required_params if event.get(param) is None]

        if missing_params:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Missing required parameters: {", ".join(missing_params)}'})
            }

        # Step 1: Calculate BMR
        bmr_result = calculate_bmr({
            'gender': gender,
            'age': age,
            'height': height,
            'weight_in_kg': weight_in_kg
        }, context)

        if bmr_result['statusCode'] != 200:
            return bmr_result

        bmr_data = json.loads(bmr_result['body'])
        bmr = bmr_data['bmr']

        # Step 2: Calculate TDEE
        tdee_result = calculate_tdee({
            'bmr': bmr,
            'activity_level': activity_level,
            'objectif': objectif
        }, context)

        if tdee_result['statusCode'] != 200:
            return tdee_result

        tdee_data = json.loads(tdee_result['body'])
        tdee = tdee_data['tdee']

        # Step 3: Calculate Macros
        macros_result = calculate_macros({
            'tdee': tdee,
            'weight_in_kg': weight_in_kg,
            'body_fat_percent': body_fat_percent
        }, context)

        if macros_result['statusCode'] != 200:
            return macros_result

        macros_data = json.loads(macros_result['body'])

        # Step 4: Create target array (similar to original get_target method)
        target_array = [
            tdee,
            macros_data['protein_cal'],
            macros_data['lipid_g'],
            macros_data['glucides_g']
        ]

        # Combine all results
        complete_profile = {
            'user_info': {
                'gender': gender,
                'age': age,
                'height': height,
                'weight_in_kg': weight_in_kg,
                'weight_in_pounds': weight_in_kg * 2.20462262185,
                'activity_level': activity_level,
                'objectif': objectif,
                'body_fat_percent': body_fat_percent
            },
            'calculations': {
                'bmr': bmr,
                'tdee': tdee,
                'lean_body_mass_kg': macros_data['lean_body_mass_kg'],
                'lean_body_mass_pounds': macros_data['lean_body_mass_kg'] * 2.20462262185
            },
            'targets': {
                'protein_g': macros_data['protein_g'],
                'protein_cal': macros_data['protein_cal'],
                'lipid_g': macros_data['lipid_g'],
                'lipid_cal': macros_data['lipid_cal'],
                'glucides_g': macros_data['glucides_g'],
                'glucides_cal': macros_data['glucides_cal']
            },
            'target_array': target_array
        }

        return {
            'statusCode': 200,
            'body': json.dumps(complete_profile)
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

# Example usage and testing
def test_functions():
    """Test function to demonstrate usage"""

    # Test data
    test_event = {
        "gender": "male",
        "age": 30,
        "height": 180,
        "weight_in_kg": 80,
        "activity_level": "moderate",
        "objectif": "maintain",
        "body_fat_percent": 0.15
    }

    # Test complete profile
    result = get_complete_nutrition_profile(test_event, None)
    print("Complete Profile Result:")
    print(json.dumps(json.loads(result['body']), indent=2))

    return result

# Uncomment to test locally
# if __name__ == "__main__":
#     test_functions()