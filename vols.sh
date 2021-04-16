ibmcloud ks clusters | grep normal | awk '{ print $ 2}' > cluster.lst

for block_id in $(ibmcloud sl block volume-list --column id --column notes --output JSON | jq '.[].id'); 
do
  cluster=$(ibmcloud sl block volume-list --column id --column notes --output JSON | jq -r ".[]|select(.id==$block_id)|.notes" | jq -r .cluster); 
  grep $cluster cluster.lst > /dev/null; 
  if [ $? -eq 1 ]; then 
    echo "cluster $cluster not found for $block_id"; 
  fi; 
done

for file_id in $(ibmcloud sl file volume-list --column id --column notes --output JSON | jq '.[].id');
do 
  cluster=$(ibmcloud sl file volume-list --column id --column notes --output JSON | jq -r ".[]|select(.id==$file_id)|.notes" | jq -r .cluster); 
  grep $cluster cluster.lst > /dev/null; 
  if [ $? -eq 1 ]; then 
    echo "cluster $cluster not found for $file_id"; 
  fi; 
done
