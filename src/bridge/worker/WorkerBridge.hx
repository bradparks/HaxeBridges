package bridge.worker;


#if flash
import flash.system.MessageChannel;
import flash.system.Worker;
import flash.system.WorkerDomain;
import flash.events.Event;
import flash.utils.ByteArray;
import haxe.Timer;


class WorkerBridge implements IBridgeType{

 
	private var mainToWorker:MessageChannel;
	private var workerToMain:MessageChannel;
	private var worker:Worker;

	private var lastId:Int = 0;
	private var handlerIds:Array<Int> = [];
	private var handlers:Array<Dynamic->Void> = [];
	

	public function new(workerBytes:ByteArray){
		//Create worker from our own loaderInfo.bytes
		worker = WorkerDomain.current.createWorker(workerBytes);
		
		//Create messaging channels for 2-way messaging
		mainToWorker = Worker.current.createMessageChannel(worker);
		workerToMain = worker.createMessageChannel(Worker.current);
		
		//Inject messaging channels as a shared property
		worker.setSharedProperty("mainToWorker", mainToWorker);
		worker.setSharedProperty("workerToMain", workerToMain);
		
		//Listen to the response from our worker
		workerToMain.addEventListener(Event.CHANNEL_MESSAGE, onWorkerToMain);
		
		worker.start();
	}

	public function call(type:Int, inst:Int, field:Int, ?params:Array<Dynamic>, ?handler:Null<Dynamic>->Void):Void{
		var id;
		if(handler!=null){
			id = lastId++;
			handlerIds.push(id);
			handlers.push( handler );
		}else{
			id = -1;
		}
		mainToWorker.send( id );
		mainToWorker.send( type );
		mainToWorker.send( inst );
		mainToWorker.send( field );
		mainToWorker.send( params );
	}
	
	//Worker >> Main
	private function onWorkerToMain(event:Event):Void {
		//Trace out whatever message the worker has sent us.
		//trace("[Worker] " + workerToMain.receive());
		while(workerToMain.messageAvailable){
			var id = workerToMain.receive();
			var result = workerToMain.receive();
			var index = handlerIds.indexOf(id);
			handlerIds.splice(index, 1);

			var handler = handlers[index];
			handlers.splice(index, 1);
			handler(result);
		}
	}
}
#end