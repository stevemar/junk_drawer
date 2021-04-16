ibmcloud ks clusters | grep normal | awk '{ print $ 2}' > cluster.lst

for block_id in $(ibmcloud sl block volume-list --column id --column notes --output JSON | jq '.[].id'); 
do
  cluster=$(ibmcloud sl block volume-list --column id --column notes --output JSON | jq -r ".[]|select(.id==$block_id)|.notes" | jq -r .cluster); 
  block_name=$(ibmcloud sl block volume-detail $block_id --output JSON | jq -r .username);
  grep $cluster cluster.lst > /dev/null; 
  if [ $? -eq 1 ]; then 
    echo "cluster $cluster not found for block ID $block_id / block name $block_name"; 
  fi; 
done

for file_id in $(ibmcloud sl file volume-list --column id --column notes --output JSON | jq '.[].id');
do 
  cluster=$(ibmcloud sl file volume-list --column id --column notes --output JSON | jq -r ".[]|select(.id==$file_id)|.notes" | jq -r .cluster); 
  file_name=$(ibmcloud sl file volume-detail $file_id --output JSON | jq -r .username);
  grep $cluster cluster.lst > /dev/null; 
  if [ $? -eq 1 ]; then 
    echo "cluster $cluster not found for file ID $file_id / file name $file_name"; 
  fi; 
done
