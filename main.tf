provider "aws" {
	region = "us-east-1"
	access_key="AKIARHFT66P3I5XIBO57"
	secret_key="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"

}


# Create S3 Bucket without ACL

resource "aws_s3_bucket" "static_site" {
 	bucket = ""
	force_destroy=true

	tags = {
	    Name = "StaticSite"
	    }
}


# Enable static website hosting

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.static_site.id
 
 index_document {
   suffix = "index.html"
 }

 error_document {
	key = "404.html"
	}
}


# Set Object Ownership

resource "aws_s3_bucket_ownership_controls" "ownership" {
	bucket=aws_s3_bucket.static_site.id

	rule {
	object_ownership = "BucketOwnerPreferred"
	}
}

resource "aws_s3_bucket_public_access_block" "public_access" {
	bucket= aws_s3_bucket.static_site.id

	block_public_acls = false
	ignore_public_acls = false
	block_public_policy = false
	restrict_public_buckets = false

}



# Add a bucket policy to allow public read access

resource "aws_s3_bucket_policy" "static_site_policy" {
	bucket = aws_s3_bucket.static_site.id

  	depends_on=[
		aws_s3_bucket_public_access_block.public_access
		]
	
      policy = jsonencode({
	 Version = "2012-10-17"
		 Statement =[{
		  Sid = "PublicReadGetObject"
		  Effect="Allow"
		  Principal="*"
                  Action ="S3:GetObject"
		  Resource = "${aws_s3_bucket.static_site.arn}/*"
		}]
	})
}
