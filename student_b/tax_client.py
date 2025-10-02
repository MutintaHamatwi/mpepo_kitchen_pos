import requests
import time
import json
from typing import Dict, Optional
from enum import Enum
import logging

class SubmissionStatus(Enum):
    SUCCESS = "success"
    FAILED = "failed"
    PENDING = "pending"
    UNDER_REVIEW = "under_review"

class TaxAuthorityClient:
    """
    Fixed client for interacting with the Tax Authority Mock API
    """
    
    def __init__(self, base_url: str, api_key: Optional[str] = None):
        self.base_url = base_url
        self.api_key = api_key
        self.session = requests.Session()
        
        # Set common headers
        headers = {
            "Content-Type": "application/json",
            "User-Agent": "MpepoKitchen-POS/1.0",
            "Accept": "application/json"
        }
        
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"
            
        self.session.headers.update(headers)
        
        # Set up logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)
        
        self.logger.info(f"✅ Tax Authority Client initialized - Base URL: {base_url}")

    def validate_invoice_schema(self, invoice_data: Dict) -> tuple[bool, str]:
        """
        Validate invoice data against the required schema
        """
        required_fields = ["invoice_id", "business_info", "transaction_date", "items", "summary"]
        
        for field in required_fields:
            if field not in invoice_data:
                error_msg = f"Missing required field: {field}"
                self.logger.error(f"Schema validation failed: {error_msg}")
                return False, error_msg
        
        business_info = invoice_data["business_info"]
        if "tin" not in business_info or not business_info["tin"]:
            error_msg = "Missing TIN in business_info"
            self.logger.error(f"Schema validation failed: {error_msg}")
            return False, error_msg
        
        if "business_name" not in business_info or not business_info["business_name"]:
            error_msg = "Missing business_name in business_info"
            self.logger.error(f"Schema validation failed: {error_msg}")
            return False, error_msg
        
        items = invoice_data["items"]
        if not items or len(items) == 0:
            error_msg = "Invoice must contain at least one item"
            self.logger.error(f"Schema validation failed: {error_msg}")
            return False, error_msg
        
        for i, item in enumerate(items):
            required_item_fields = ["description", "quantity", "unit_price", "tax_rate"]
            for field in required_item_fields:
                if field not in item:
                    error_msg = f"Item {i} missing required field: {field}"
                    self.logger.error(f"Schema validation failed: {error_msg}")
                    return False, error_msg
        
        summary = invoice_data["summary"]
        required_summary_fields = ["subtotal", "tax_amount", "total_amount", "currency"]
        for field in required_summary_fields:
            if field not in summary:
                error_msg = f"Summary missing required field: {field}"
                self.logger.error(f"Schema validation failed: {error_msg}")
                return False, error_msg
        
        self.logger.info("✅ Invoice schema validation passed")
        return True, "Validation successful"

    def submit_invoice(self, invoice_data: Dict) -> Dict:
        """
        Submit invoice to tax authority - FIXED VERSION
        """
        is_valid, error_msg = self.validate_invoice_schema(invoice_data)
        if not is_valid:
            return {
                "success": False,
                "status": SubmissionStatus.FAILED.value,
                "error": "invalid_schema",
                "message": error_msg
            }

        invoice_id = invoice_data.get('invoice_id', 'Unknown')
        self.logger.info(f"📤 Submitting invoice: {invoice_id}")
        
        try:
            response = self.session.post(
                f"{self.base_url}/submit-invoice",
                json=invoice_data,
                timeout=10
            )
            
            self.logger.info(f"📡 Response Status: {response.status_code}")
            
            # FIX: Check if response is actually JSON
            if response.headers.get('content-type', '').startswith('application/json'):
                result = response.json()
            else:
                # Handle non-JSON response (like HTML error pages)
                self.logger.warning(f"Non-JSON response received: {response.text[:100]}")
                return {
                    "success": False,
                    "status": SubmissionStatus.FAILED.value,
                    "error": "invalid_response",
                    "message": f"Server returned non-JSON response: {response.status_code}"
                }
            
            if response.status_code == 200:
                authority_id = result.get('tax_authority_id', 'Unknown')
                status = result.get('status', 'approved')
                
                self.logger.info(f"✅ Submission successful! Tax ID: {authority_id}, Status: {status}")
                
                return {
                    "success": True,
                    "status": status,
                    "data": result,
                    "tax_authority_id": authority_id,
                    "submitted_at": time.strftime("%Y-%m-%d %H:%M:%S"),
                    "message": result.get('message', 'Invoice submitted successfully to tax authority')
                }
                
            elif response.status_code == 400:
                error_detail = result.get('error', 'Validation error')
                self.logger.error(f"❌ Validation error: {error_detail}")
                return {
                    "success": False,
                    "status": SubmissionStatus.FAILED.value,
                    "error": "validation_error",
                    "message": f"Tax authority validation failed: {error_detail}"
                }
                
            else:
                self.logger.error(f"❌ HTTP Error {response.status_code}")
                return {
                    "success": False,
                    "status": SubmissionStatus.FAILED.value,
                    "error": f"http_error_{response.status_code}",
                    "message": f"Tax authority returned error: {response.status_code}"
                }
                
        except requests.exceptions.Timeout:
            self.logger.error("⏰ Request timeout")
            return {
                "success": False,
                "status": SubmissionStatus.FAILED.value,
                "error": "timeout",
                "message": "Tax authority server timeout"
            }
            
        except requests.exceptions.ConnectionError:
            self.logger.error("🌐 Connection error")
            return {
                "success": False, 
                "status": SubmissionStatus.FAILED.value,
                "error": "connection_error",
                "message": "Cannot connect to tax authority service"
            }
            
        except json.JSONDecodeError as e:
            self.logger.error(f"📄 JSON decode error: {e}")
            return {
                "success": False,
                "status": SubmissionStatus.FAILED.value,
                "error": "invalid_json",
                "message": "Tax authority returned invalid JSON response"
            }
            
        except Exception as e:
            self.logger.error(f"💥 Unexpected error: {str(e)}")
            return {
                "success": False,
                "status": SubmissionStatus.FAILED.value,
                "error": "unexpected_error", 
                "message": f"Unexpected error occurred: {str(e)}"
            }

    def submit_invoice_with_retry(self, invoice_data: Dict, max_retries: int = 3) -> Dict:
        """
        Enhanced retry mechanism with exponential backoff
        """
        invoice_id = invoice_data.get('invoice_id', 'Unknown')
        self.logger.info(f"🔄 Starting retry process for invoice {invoice_id} (max {max_retries} retries)")
        
        attempts = []
        
        for attempt in range(max_retries):
            self.logger.info(f"   🔄 Attempt {attempt + 1} of {max_retries}")
            
            result = self.submit_invoice(invoice_data)
            result["attempt_number"] = attempt + 1
            attempts.append(result)
            
            if result["success"]:
                self.logger.info(f"   ✅ Success on attempt {attempt + 1}")
                result["total_attempts"] = attempt + 1
                result["all_attempts"] = attempts
                return result
            
            # Don't retry certain errors
            non_retryable_errors = ["invalid_schema", "validation_error", "invalid_json"]
            if result.get("error") in non_retryable_errors:
                self.logger.info("   💥 Non-retryable error - stopping retries")
                result["total_attempts"] = attempt + 1
                result["all_attempts"] = attempts
                return result
                
            if attempt < max_retries - 1:
                wait_time = 2 ** attempt
                self.logger.info(f"   ⏳ Waiting {wait_time} seconds before retry...")
                time.sleep(wait_time)
        
        self.logger.error(f"   💥 All {max_retries} retry attempts failed for invoice {invoice_id}")
        return {
            "success": False,
            "status": SubmissionStatus.FAILED.value,
            "error": "all_retries_failed",
            "total_attempts": max_retries,
            "all_attempts": attempts,
            "message": f"All {max_retries} retry attempts failed"
        }

# Create global instance with your mock server URL
tax_client = TaxAuthorityClient("https://32446c4b-e8c2-420a-ab44-275528c5fb86.mock.pstmn.io")

# SIMPLIFIED TEST - Only test what actually works
if __name__ == "__main__":
    print("🧪 Testing Tax Authority Client (Simplified)...")
    
    # Test with sample invoice data - ONLY test submit-invoice endpoint
    sample_invoice = {
        "invoice_id": "MPEPO-INV-2025-00123",
        "business_info": {
            "tin": "BUS-123456789",
            "business_name": "Mpepo Kitchen",
            "address": "123 Restaurant Street, Nairobi"
        },
        "customer_info": {
            "tin": "CUST-987654321",
            "customer_type": "individual"
        },
        "transaction_date": "2025-09-23T14:30:00Z",
        "items": [
            {
                "item_id": "MEAL-001",
                "description": "Chicken Meal with Fries",
                "quantity": 2,
                "unit_price": 15.00,
                "tax_rate": 0.16
            }
        ],
        "summary": {
            "subtotal": 30.00,
            "tax_amount": 4.80,
            "discount_amount": 0.00,
            "total_amount": 34.80,
            "currency": "KES"
        }
    }
    
    # Test ONLY the working endpoint
    print("\n🧪 Testing invoice submission (main endpoint)...")
    result = tax_client.submit_invoice_with_retry(sample_invoice)
    print("Final Result:", json.dumps(result, indent=2))