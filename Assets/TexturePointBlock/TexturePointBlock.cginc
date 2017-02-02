
typedef float4x4 TTexturePointBlock;

#define TTEXTUREPOINTBLOCK_MAX	60
int TexturePointBlockCount;
#define TexturePointBlockOffset	0	//	when we were sharing block data, but doesnt happen now?
TTexturePointBlock TexturePointBlocks[TTEXTUREPOINTBLOCK_MAX];


float3 TInstanceCache_BoundsMin(TTexturePointBlock Block)
{
	return Block[0];
}

float3 TTexturePointBlock_BoundsMax(TTexturePointBlock Block)
{
	return Block[1];
}

int TTexturePointBlock_DataTextureIndexOffset(TTexturePointBlock Block)
{
	return Block[2].x;
}

int TTexturePointBlock_PointCount(TTexturePointBlock Block)
{
	return Block[2].y;
}

float TTexturePointBlock_Lod(TTexturePointBlock Block)
{
	return Block[2].z;
}

int TTexturePointBlock_LodPointCount(TTexturePointBlock Block)
{
	int PointCount = TTexturePointBlock_PointCount( Block );
	float Lod = TTexturePointBlock_Lod( Block );
	return PointCount * Lod;
}

bool TTexturePointBlock_IsValid(TTexturePointBlock Block)
{
	return Block[2].w == 0;
}

float TTexturePointBlock_Randomf(TTexturePointBlock Block)
{
	return Block[3].x;
}

TTexturePointBlock GetInvalidTTexturePointBlock()
{
	return float4x4(	0,0,0,0,	0,0,0,0,	0,0,0,-1,	0,0,0,0 );
}

void GetTexturePointBlock(out TTexturePointBlock Block,int TriangleIndex,out int BlockSubIndex)
{
	//	iterate over all until we find Nth particle data
	int RunningIndex = 0;
	int BlockIndex = -1;
	BlockSubIndex = 0;

	for ( int ii=TexturePointBlockOffset;	ii<TTEXTUREPOINTBLOCK_MAX;	ii++ )
	{
		int i = ii;

		if ( i >= TexturePointBlockCount )
		{
			RunningIndex = 99999;
			return;
		}

		int BlockPointCount = TTexturePointBlock_LodPointCount( TexturePointBlocks[i] );
		if ( TriangleIndex >= RunningIndex + BlockPointCount )
		{
			RunningIndex += BlockPointCount;
			continue;
		}
		else
		{
			BlockIndex = i;
			BlockSubIndex = (TriangleIndex - RunningIndex);
			TriangleIndex = 99999;
			break;
		}
	}

	int i = BlockIndex;
	int BlockPointCount = TTexturePointBlock_LodPointCount( TexturePointBlocks[i] );
	float Lod = TTexturePointBlock_Lod( TexturePointBlocks[i] );
	int BlockFullPointCount = TTexturePointBlock_PointCount( TexturePointBlocks[i] );

	//	linear index scale means blocks are culled non-randomly
	//BlockSubIndex = BlockSubIndex * Lod;
	float BlockSubIndexf = Range( 0, BlockPointCount, BlockSubIndex );
	BlockSubIndex = BlockFullPointCount * BlockSubIndexf;
	//BlockSubIndex = (TriangleIndex - RunningIndex) * Lod;
	Block = TexturePointBlocks[i];
}

