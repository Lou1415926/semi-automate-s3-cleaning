#!/bin/bash

buckets=$(aws s3api list-buckets --query "sort_by(Buckets, &CreationDate)[]" | jq -c ".[]")

for bucket in $buckets 
{
	bucket_name=$(echo $bucket | jq '.Name' -r)
	bucket_creation_date=$(echo $bucket | jq '.CreationDate')

	if grep -q "do-not-delete" <<< "$bucket_name"; then
		# We don't want to delete pipeline with name that contains the "do-not-delete" keyword.
		# Don't even list it.
		continue
	fi
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "  Name: ${bucket_name}"
	echo "  Created At: ${bucket_creation_date}"
	echo -n "Do you want to permanently empty and delete it? (\"Y\" to confirm; o/w skip): "
	read -r confirmDeletion

	if [ ! $confirmDeletion == "Y" ]; then
		echo "[Skipped]"
		continue
	fi


	# First empty the bucket by deleting all versioned object and markers within the bucket.
	out=$(aws s3api list-object-versions \
	    --bucket ${bucket_name} \
	    --output=json \
	    --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')
	num=$(echo $out | jq '.Objects | length')
	if [ ! $num == 0 ]; then
		aws s3api delete-objects --bucket ${bucket_name} --delete "${out}"
	fi

	out=$(aws s3api list-object-versions --bucket ${bucket_name} \
	--query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')
	num=$(echo $out | jq '.Objects | length')
	if [ ! $num == 0 ]; then
		aws s3api delete-objects --bucket ${bucket_name} --delete "${out}"
	fi

	aws s3api delete-bucket --bucket $bucket_name
}

