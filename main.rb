#coding: utf-8
require 'bundler'
Bundler.require
require 'open-uri'
require 'pp' 
require 'date'
require 'csv'
require 'fileutils'

require './account'
require './GmailSend'

def main()
	getDate=Date.today#データ取得日及び表示日の範囲
	storagePath='csv/'#日付別の決算企業ファイルの保存パス
	readFileName='../holdStockList.csv'
	isStdIoScreen=true
	logPath='log/log.txt'

	FileUtils.mkdir_p('csv') unless FileTest.exist?('csv')
	
	#本日の保有銘柄の決算リストを取得、表示
	readDateToSite(getDate,storagePath)
	kessanList=showHoldStock(getDate,readFileName,storagePath)
	
	p kessanList[0]
	if kessanList[0] == nil
		str="本日、保有銘柄の決算はありません\n"
	else
		str="本日の保有銘柄の決算は\n"
		kessanList.each do |code|
			str=str+code.to_s+"\n"
		end
	end
	pp str
	#本日のすべての決算リストを取得、表示
	allKessanList=showAllData(getDate,storagePath)	
	pp allKessanList
	if allKessanList[0] == nil
		str+="\n本日の決算銘柄はありません\n"
	else
		str+="本日の決算銘柄は\n"
		allKessanList.each do |code|
			str=str+code.to_s+"\n"
		end
	end

	gmail=GmailSend.new('ikimono.miwa589@gmail.com',$password)
	gmail.sendMail('stockInfo589@gmail.com','本日の決算銘柄',str)

end

def readDateToSite(getDate,storagePath)
	#現在決算銘柄を保存したcsvファイルを削除
	Dir.glob(storagePath+"*").each do |file|
		File.delete file
	end
	saveKessanToCsv(getDate,storagePath)
end

def saveKessanToCsv(getDate,storagePath)
	isNextPage=false
	#その日の決算銘柄をCSVに保存
	dateStr=getDate.strftime("%Y%m%d")
	page=1
	csv=CSV.open(storagePath+dateStr+'.csv','wb')
	begin
		isNextPage=false 
		url='http://kabuyoho.ifis.co.jp/index.php?action=tp1&sa=schedule&ym='+dateStr[0..5]+'&lst='+dateStr+'&pageID='+page.to_s
		p url
		doc=getHtmlData(url)
		
		doc.xpath('//tr[@class="line"]').each do |node|
			data=Array.new
			node.xpath('./td/a').each do |node1|
				data.push(node1.text)
			end
			csv<<data
		end
		page+=1
		#次のページがあるかどうか
		if doc.xpath('//a[@title="next page"]').empty? ==false
			isNextPage=true
		end
	end while isNextPage==true
	csv.close
end

def showAllData(getDate,storagePath)
	holdStockList=Array.new
	holdStockList[0]='all'
	list=searchCsv(getDate,holdStockList,storagePath)	

	return list
end



def showHoldStock(getDate,readFileName,storagePath)
	begin
		tmpHoldStockList=CSV.read(readFileName)
	rescue Errno::ENOENT
		puts readFileName+'がありません'
		return -1
	end 
	tmpHoldStockList.delete_at(0)
	holdStockList=Array.new
	tmpHoldStockList.length.times do |i|
		holdStockList[i]=Hash.new
		holdStockList[i]['code']=tmpHoldStockList[i][0].to_i
		holdStockList[i]['isNot']=true;
	end
	kessanList=searchCsv(getDate,holdStockList,storagePath)
	
	return kessanList
end

def getHtmlData(url)	
	html=open(url).read
	doc=Nokogiri::HTML.parse(html,nil,'utf-8')
	#p doc.title

	return doc
end


def searchCsv(getDate,searchStockList,storagePath)

	if searchStockList[0] =='all'
		isShowAll =true
	else
		isShowAll =false
	end

	kessanList=Array.new
	
	#検索
	isDayShowItem=false
	dateStr=getDate.strftime("%Y%m%d")
	begin 
		csv=CSV.open(storagePath+dateStr+'.csv',"r") 
	rescue Errno::ENOENT
		puts "openエラー"
		return -1;
	end	
	csv.each do |row|
		if isShowAll==true
			kessanList.push(row[0]+':'+row[1])
		else
			searchStockList.each do |search|
				if row[0].to_i ==search['code']#見つかった
					kessanList.push(search['code'].to_s+':'+row[1])
					search['isNot']=false
				end
			end
		end
	end
	csv.close
	
	return kessanList
end

main()
