var sharedData = null
var chart = null

const onSelectChange = (data) =>{
	getData("https://raw.githubusercontent.com/henomis/covid-go/main/data/"+document.getElementById("country").value + "_" + data+".json")
}

const onRangeChange = () => {
	console.log("UPDATE")

	chart.data.labels =  [...sharedData.data.labels]
	chart.data.datasets = [...sharedData.data.datasets]

	console.log(chart.data.labels.length, sharedData.data.labels.length)
	

	const offset = document.getElementById("customRange").value

	for (i=0;i<offset;i++) {
		chart.data.labels.pop();
    	chart.data.datasets.forEach((dataset) => {
        	dataset.data.pop();
    	});
	}

	chart.update()
	
}

const getData = (dataFile) => {
fetch(dataFile)
 .then(response => response.text())
    .then(data => {

		rawData = JSON.parse(data)
		sharedData =  {...rawData}
		console.log("update data")	

		range = document.getElementById("customRange")
		range.setAttribute('max',rawData.data.labels.length)
		range.value = 0


		if (chart == null) {
			console.log("new chart")
			var ctx = myAreaChart.getContext('2d');
			chart = new Chart(ctx,rawData);
		} else {
			console.log("update chart")
			chart.data = rawData.data
			chart.update()
		}
    })
}

