**create s3 bucket**

aws s3api create-bucket \\

  --bucket my-terraform-state-bucket-12345 \\
  
  --region ap-south-1 \\
  
  --create-bucket-configuration LocationConstraint=ap-south-1


**Enable versioning:**

aws s3api put-bucket-versioning \\

  --bucket my-terraform-state-bucket-12345 \\
  
  --versioning-configuration Status=Enabled

**Create DynamoDB table (for locking):**

aws dynamodb create-table \\

  --table-name terraform-lock-table \\
  
  --attribute-definitions AttributeName=LockID,AttributeType=S \\
  
  --key-schema AttributeName=LockID,KeyType=HASH \\
  
  --billing-mode PAY_PER_REQUEST \\
  
  --region ap-south-1








  ingress {
  
    from_port   = 8000
    
    to_port     = 8000
    
    protocol    = "tcp"
    
    cidr_blocks = ["49.204.123.10/32"]
    
  }

  ingress {
  
    from_port   = 3000
    
    to_port     = 3000
    
    protocol    = "tcp"
    
    cidr_blocks = ["0.0.0.0/0"]
    
  }

ingress {

    from_port   = 8080
    
    to_port     = 8080
    
    protocol    = "tcp"
    
    cidr_blocks = ["49.204.123.10/32"]
    
  }
